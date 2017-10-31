fs = require('fs')
YAML = require('js-yaml')
{ abstractClass, isImplementation } = require('./abstraction.js')

class DatabaseSerializer
    F_serialize: null
    F_deserialize: null

DatabaseSerializer = abstractClass(DatabaseSerializer, (cls) ->
    cls.database = (filename) ->
        return new Database(filename, cls)
)

class YAMLSerializer
    serialize: (o) -> YAML.safeDump(o, {
        indent: 4
        lineWidth: 175
        
    })
    deserialize: YAML.safeLoad

class JSONSerializer
    serialize: JSON.parse
    deserialize = JSON.parse

YAMLSerializer = DatabaseSerializer.apply(YAMLSerializer)
JSONSerializer = DatabaseSerializer.apply(JSONSerializer)

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
    constructor: (@filename, @serializer) ->
        try
            if fs.statSync(@filename).isFile()
                @data = @serializer.deserialize(fs.readFileSync(@filename))

            else
                throw new Error("If you are seeing this, something is wrong with this control block.")

        catch err
            @data = {}
        
        if (typeof @serializer) is 'function'
            @serializer = new @serializer()

    objectFrom: (obj) =>
        res = {
            spec: {
                serialization: null
                type: null  
                primitive: false
            }
            obj: null
        }

        if isImplementation(obj, DBSerializable)
            res.obj = obj.toObject()
            res.spec.type = "DBSerializable"
            res.spec.serialization = obj.constructor.name

        else if typeof obj != 'object'
            if (typeof obj) not in ['string', 'number', 'array', 'boolean']
                throw new Error("#{obj} must be a subclass of abstract type DBSerializable! (use DBSerializable.apply(myClass) if obj is an instance of myClass and myClassi implements such methods)")

            else
                res.obj = obj

                res.spec.type = typeof obj
                res.spec.primitive = true

        else if obj == null # includes undefined
            res.obj = obj
            res.spec.primitive = true

        else
            if not res.spec.type?
                res.spec.type = "object"

            res.obj = {}

            for k, v of obj
                res.obj[k] = @objectFrom(v)

        return res

    unfreeze: (d) =>
        res = null

        if d.spec.type is "DBSerializable"
            if d.spec.serialization?
                d.obj = _serTypes[d.spec.serialization].fromObject(d.obj)

            else
                throw new Error("DBSerializable-based object '#{d.obj}' does not specify the serializing class in its spec structure")

        else if d.spec.primitive
            res = d.obj

        else if d.spec.type is "object"
            o = {}

            for k, v of d.obj
                o[k] = @unfreeze(v)

            res = o

        else
            throw new Error("Object '#{d.obj}' does not specify a supported spec structure type ('#{d.spec.type}' is a currently unsupported format)")

        return res

    _loadFile: =>
        try
            if not fs.statSync(@filename).isFile()
                throw new Error("If you are seeing this, something is wrong with this control block.")

        catch err
            return @data || {}

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

    # entry point inheritance
    abstractClass: abstractClass
    isImplementation: isImplementation
}