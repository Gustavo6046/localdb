fs = require('fs')
YAML = require('js-yaml')
BSON = new (require('bson'))()
GZIP = require('pako')
zlib = require('zlib')
{ abstractClass, isImplementation } = require('./abstraction.js')
compjs = require('compressjs')

class DatabaseSerializer
    F_serialize: null
    F_deserialize: null

DatabaseSerializer = abstractClass(DatabaseSerializer, (cls) ->
    cls.database = (filename, debug) ->
        return new Database(filename, cls, debug)
)

class JSONSerializer
    serialize: JSON.stringify
    deserialize: JSON.parse

class YAMLSerializer
    serialize: (o) -> YAML.safeDump(o, {
        indent: 4
        lineWidth: 175
    })
    deserialize: YAML.safeLoad

class BSONSerializer
    serialize: BSON.serialize
    deserialize: BSON.deserialize

JSONSerializer = DatabaseSerializer.apply(JSONSerializer)
YAMLSerializer = DatabaseSerializer.apply(YAMLSerializer)
BSONSerializer = DatabaseSerializer.apply(BSONSerializer)

gzipped = (ser) ->  # for compatibility purposes
    class GZipped
        serialize: (o) ->
            new Buffer(GZIP.deflate(ser.prototype.serialize(o)))

        deserialize: (o) ->
            ser.prototype.deserialize(new Buffer(GZIP.inflate(o)))

    GZipped.name += ser.name
    GZipped = DatabaseSerializer.apply(GZipped)

    return GZipped

compressions = {
    gzip: [zlib.gzipSync, zlib.gunzipSync]
    inflate: [zlib.deflateSync, zlib.inflateSync]
    bzip2: [compjs.Bzip2.compressFile, compjs.Bzip2.decompressFile]
    bwtc: [compjs.BWTC.compressFile, compjs.BWTC.decompressFile]
    lzp3: [compjs.Lzp3.compressFile, compjs.Lzp3.decompressFile]
    ppm: [compjs.PPM.compressFile, compjs.PPM.decompressFile]
}

compressed = (ser, compression) ->
    if not compressions[compression = compression.toLowerCase()]?
        throw new Error("No such compression currently available with shelfdb!")

    class Compressed
        serialize: (o) ->
            new Buffer(compressions[compression][0](new Buffer(ser.prototype.serialize(o))))

        deserialize: (o) ->
            ser.prototype.deserialize(new Buffer(compressions[compression][1](o)))

    Compressed.name += ser.name
    Compressed = DatabaseSerializer.apply(Compressed)

    return Compressed

# =======================

_serTypes = {}

class DBSerializable
    F_toObject: null
    S_fromObject: null

DBSerializable = abstractClass(DBSerializable, (cls) ->
    _serTypes[cls.name] = cls
)

# =======================

class Database
    constructor: (@filename, @serializer, @debug) ->
        if not @debug? then @debug = false

        try
            if fs.statSync(@filename).isFile()
                @data = @serializer.deserialize(fs.readFileSync(@filename))

            else
                throw new Error("If you are seeing this, something is wrong with this control block.")

        catch err
            @data = {}
        
        if (typeof @serializer) is 'function'
            @serializer = new @serializer()

    objectFrom: (obj, pkey, parent) =>
        if not parent? then parent = null
        if not pkey? then pkey = null

        if @debug == 2
            console.log("Attempting to get object from:")
            console.log(obj)

        res = {
            spec: {
                serialization: null
                type: null
                primitive: false
            }
            obj: null
        }

        if obj? and isImplementation(obj.constructor, DBSerializable)
            res.spec.type = "DBSerializable"
            res.spec.serialization = obj.constructor.name

            if @debug == 1
                console.log("Found DBSerializable of type #{obj.constructor.name}#{if pkey? then " (and key '#{pkey}')" else ''}")

            res.obj = {}

            for k, v of obj.toObject()
                res.obj[k] = @objectFrom(v, k, obj)
                
        else if not obj?
            res.spec.type = "nil"
            res.spec.primitive = true
            res.obj = obj

        else if (typeof obj) isnt 'object'
            if (typeof obj) not in ['string', 'number', 'boolean']
                throw new Error("#{obj}#{if parent? then " (from key '#{pkey}' in parent with keys '#{Object.keys(parent).join(', ')}')" else ""} must be a primitive, non-instance object, array, or implement the abstract type DBSerializable!")

            else
                res.obj = obj

                res.spec.type = typeof obj
                res.spec.primitive = true

        else if Array.isArray(obj)
            arr = []

            for o in obj
                arr.push(@objectFrom(o))

            res.obj = arr
            res.spec.type = 'array'
            res.spec.primitive = false

        else if obj == null # includes undefined
            res.obj = null
            res.spec.primitive = true

        else
            if not res.spec.type?
                res.spec.type = "object"

            res.obj = {}

            for k, v of obj
                res.obj[k] = @objectFrom(v, k, obj)

        return res

    unfreeze: (d) =>
        try
            res = null

            if d.spec.type is "DBSerializable"
                ud = {}

                for k, v of d.obj
                    ud[k] = @unfreeze(v)

                if d.spec.serialization? and d.spec.serialization in Object.keys(_serTypes)
                    res = _serTypes[d.spec.serialization].fromObject(ud)

                else if d.spec.serialization not in Object.keys(_serTypes)
                    throw new Error("DBSerializable-based object '#{d.obj}' specifies an unsupported serialization type '#{d.spec.serialization}'! (try loading the module with the serialization)")

                else
                    throw new Error("DBSerializable-based object '#{d.obj}' does not specify the serializing class in its spec structure")

            else if d.spec.primitive
                res = d.obj

            else if d.spec.type is "array"
                res = []

                for item in d.obj
                    res.push(@unfreeze(item))

            else if d.spec.type is "object"
                res = {}

                for k, v of d.obj
                    res[k] = @unfreeze(v)

            else
                throw new Error("Object '#{d.obj}' does not specify a supported spec structure type ('#{d.spec.type}' is a currently unsupported format)")

            return res

        catch e
            if d.spec? 
                if not d.spec.primitive
                    console.log("Error unfreezing object with keys '#{Object.keys(d.obj).join(', ')}' and spec..")
                    console.log(d.spec)

                else
                    console.log("Error unfreezing object '#{d.obj}' with spec...")
                    console.log(d.spec)

            else
                console.log("Error unfreezing object...")
                console.log(d)

            throw e

    _loadFile: =>
        try
            if not fs.statSync(@filename).isFile()
                throw new Error("If you are seeing this, something is wrong with this control block.")

        catch err
            return @data or {}

        data = @serializer.deserialize(fs.readFileSync(@filename))

        return @unfreeze(data)

    load: =>
        @data = @_loadFile()

    save: =>
        fs.writeFileSync(@filename, @serialize(@data))

    serialize: (obj) =>
        return @serializer.serialize(@objectFrom(obj))

    parsePath: (path, separator) ->
        if (typeof path) is "string"
            path = path
                .match(new RegExp("(?:\\\\.|[^\\#{separator[0]}])+", 'g'))
                .map((x) -> x.split("\\.").join("."))

        return path

    put: (path, value, separator, obj) =>
        if not separator? then separator = '.'

        path = @parsePath(path, separator)
        first = false

        if not obj?
            @load()
            first = true
            obj = @data
        
        if path.length > 1
            if not obj[path[0]]?
                obj[path[0]] = {}

            obj[path[0]] = @put(path.slice(1), value, separator, obj[path[0]])

        else
            obj[path[0]] = value

        if first
            @data = obj
            @save()

            return path.map((x) -> x.split('.').join('\\.')).join(".")

        else
            return obj

    get: (path, separator) =>
        if not separator? then separator = '.'

        @load()

        path = @parsePath(path, separator)
        o = @data

        for p in path
            if not o[p]?
                return null

            o = o[p]

        return o

    append: (path, value, separator) =>
        o = @get(path, separator)

        if not o?
            o = [value]

        else if typeof o isnt "array"
            return null

        else
            o.push(value)

        return @put(path, o, separator)

module.exports = {
    DBSerializable: DBSerializable
    Database: Database
    DatabaseSerializer: DatabaseSerializer

    JSONSerializer: JSONSerializer
    YAMLSerializer: YAMLSerializer
    BSONSerializer: BSONSerializer

    gzipped: gzipped
    compressed: compressed
    compressions: compressions

    # entry point inheritance
    abstractClass: abstractClass
    isImplementation: isImplementation
}