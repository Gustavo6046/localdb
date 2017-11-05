// Generated by CoffeeScript 1.12.6
var DBSerializable, Database, DatabaseSerializer, JSONSerializer, YAML, YAMLSerializer, _serTypes, abstractClass, fs, isImplementation, ref,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

fs = require('fs');

YAML = require('js-yaml');

ref = require('./abstraction.js'), abstractClass = ref.abstractClass, isImplementation = ref.isImplementation;

DatabaseSerializer = (function() {
  function DatabaseSerializer() {}

  DatabaseSerializer.prototype.F_serialize = null;

  DatabaseSerializer.prototype.F_deserialize = null;

  return DatabaseSerializer;

})();

DatabaseSerializer = abstractClass(DatabaseSerializer, function(cls) {
  return cls.database = function(filename, debug) {
    return new Database(filename, cls, debug);
  };
});

YAMLSerializer = (function() {
  function YAMLSerializer() {}

  YAMLSerializer.prototype.serialize = function(o) {
    return YAML.safeDump(o, {
      indent: 4,
      lineWidth: 175
    });
  };

  YAMLSerializer.prototype.deserialize = YAML.safeLoad;

  return YAMLSerializer;

})();

JSONSerializer = (function() {
  function JSONSerializer() {}

  JSONSerializer.prototype.serialize = JSON.stringify;

  JSONSerializer.prototype.deserialize = JSON.parse;

  return JSONSerializer;

})();

YAMLSerializer = DatabaseSerializer.apply(YAMLSerializer);

JSONSerializer = DatabaseSerializer.apply(JSONSerializer);

_serTypes = {};

DBSerializable = (function() {
  function DBSerializable() {}

  DBSerializable.prototype.F_toObject = null;

  DBSerializable.prototype.S_fromObject = null;

  return DBSerializable;

})();

DBSerializable = abstractClass(DBSerializable, function(cls) {
  return _serTypes[cls.name] = cls;
});

Database = (function() {
  function Database(filename1, serializer, debug1) {
    var err;
    this.filename = filename1;
    this.serializer = serializer;
    this.debug = debug1;
    this.append = bind(this.append, this);
    this.get = bind(this.get, this);
    this.put = bind(this.put, this);
    this.serialize = bind(this.serialize, this);
    this.save = bind(this.save, this);
    this.load = bind(this.load, this);
    this._loadFile = bind(this._loadFile, this);
    this.unfreeze = bind(this.unfreeze, this);
    this.objectFrom = bind(this.objectFrom, this);
    if (this.debug == null) {
      this.debug = false;
    }
    try {
      if (fs.statSync(this.filename).isFile()) {
        this.data = this.serializer.deserialize(fs.readFileSync(this.filename));
      } else {
        throw new Error("If you are seeing this, something is wrong with this control block.");
      }
    } catch (error) {
      err = error;
      this.data = {};
    }
    if ((typeof this.serializer) === 'function') {
      this.serializer = new this.serializer();
    }
  }

  Database.prototype.objectFrom = function(obj, pkey, parent) {
    var arr, i, k, len, o, ref1, ref2, res, v;
    if (parent == null) {
      parent = null;
    }
    if (pkey == null) {
      pkey = null;
    }
    if (this.debug === 2) {
      console.log("Attempting to get object from:");
      console.log(obj);
    }
    res = {
      spec: {
        serialization: null,
        type: null,
        primitive: false
      },
      obj: null
    };
    if ((obj != null) && isImplementation(obj.constructor, DBSerializable)) {
      res.spec.type = "DBSerializable";
      res.spec.serialization = obj.constructor.name;
      if (this.debug === 1) {
        console.log("Found DBSerializable of type " + obj.constructor.name + (pkey != null ? " (and key '" + pkey + "')" : ''));
      }
      res.obj = {};
      ref1 = obj.toObject();
      for (k in ref1) {
        v = ref1[k];
        res.obj[k] = this.objectFrom(v, k, obj);
      }
    } else if ((typeof obj) !== 'object') {
      if ((ref2 = typeof obj) !== 'string' && ref2 !== 'number' && ref2 !== 'boolean') {
        throw new Error("" + obj + (parent != null ? " (from key '" + pkey + "' in parent with keys '" + (Object.keys(parent).join(', ')) + "')" : "") + " must be a primitive, non-instance object, array, or implement the abstract type DBSerializable!");
      } else {
        res.obj = obj;
        res.spec.type = typeof obj;
        res.spec.primitive = true;
      }
    } else if (Array.isArray(obj)) {
      arr = [];
      for (i = 0, len = obj.length; i < len; i++) {
        o = obj[i];
        arr.push(this.objectFrom(o));
      }
      res.obj = arr;
      res.spec.type = 'array';
      res.spec.primitive = false;
    } else if (obj === null) {
      res.obj = null;
      res.spec.primitive = true;
    } else {
      if (res.spec.type == null) {
        res.spec.type = "object";
      }
      res.obj = {};
      for (k in obj) {
        v = obj[k];
        res.obj[k] = this.objectFrom(v, k, obj);
      }
    }
    return res;
  };

  Database.prototype.unfreeze = function(d) {
    var e, i, item, k, len, ref1, ref2, ref3, ref4, ref5, res, ud, v;
    try {
      res = null;
      if (d.spec.type === "DBSerializable") {
        ud = {};
        ref1 = d.obj;
        for (k in ref1) {
          v = ref1[k];
          ud[k] = this.unfreeze(v);
        }
        if ((d.spec.serialization != null) && (ref2 = d.spec.serialization, indexOf.call(Object.keys(_serTypes), ref2) >= 0)) {
          res = _serTypes[d.spec.serialization].fromObject(ud);
        } else if (ref3 = d.spec.serialization, indexOf.call(Object.keys(_serTypes), ref3) < 0) {
          throw new Error("DBSerializable-based object '" + d.obj + "' specifies an unsupported serialization type '" + d.spec.serialization + "'! (try loading the module with the serialization)");
        } else {
          throw new Error("DBSerializable-based object '" + d.obj + "' does not specify the serializing class in its spec structure");
        }
      } else if (d.spec.primitive) {
        res = d.obj;
      } else if (d.spec.type === "array") {
        res = [];
        ref4 = d.obj;
        for (i = 0, len = ref4.length; i < len; i++) {
          item = ref4[i];
          res.push(this.unfreeze(item));
        }
      } else if (d.spec.type === "object") {
        res = {};
        ref5 = d.obj;
        for (k in ref5) {
          v = ref5[k];
          res[k] = this.unfreeze(v);
        }
      } else {
        throw new Error("Object '" + d.obj + "' does not specify a supported spec structure type ('" + d.spec.type + "' is a currently unsupported format)");
      }
      return res;
    } catch (error) {
      e = error;
      if (d.spec != null) {
        if (!d.spec.primitive) {
          console.log("Error unfreezing object with keys '" + (Object.keys(d.obj).join(', ')) + "' and spec..");
          console.log(d.spec);
        } else {
          console.log("Error unfreezing object '" + d.obj + "' with spec...");
          console.log(d.spec);
        }
      } else {
        console.log("Error unfreezing object...");
        console.log(d);
      }
      throw e;
    }
  };

  Database.prototype._loadFile = function() {
    var data, err;
    try {
      if (!fs.statSync(this.filename).isFile()) {
        throw new Error("If you are seeing this, something is wrong with this control block.");
      }
    } catch (error) {
      err = error;
      return this.data || {};
    }
    data = this.serializer.deserialize(fs.readFileSync(this.filename));
    return this.unfreeze(data);
  };

  Database.prototype.load = function() {
    return this.data = this._loadFile();
  };

  Database.prototype.save = function() {
    return fs.writeFileSync(this.filename, this.serialize(this.data));
  };

  Database.prototype.serialize = function(obj) {
    return this.serializer.serialize(this.objectFrom(obj));
  };

  Database.prototype.parsePath = function(path, separator) {
    if ((typeof path) === "string") {
      path = path.match(new RegExp("(?:\\\\.|[^\\" + separator[0] + "])+", 'g')).map(function(x) {
        return x.split("\\.").join(".");
      });
    }
    return path;
  };

  Database.prototype.put = function(path, value, separator, obj) {
    var first;
    if (separator == null) {
      separator = '.';
    }
    path = this.parsePath(path, separator);
    first = false;
    if (obj == null) {
      this.load();
      first = true;
      obj = this.data;
    }
    if (path.length > 1) {
      if (obj[path[0]] == null) {
        obj[path[0]] = {};
      }
      obj[path[0]] = this.put(path.slice(1), value, separator, obj[path[0]]);
    } else {
      obj[path[0]] = value;
    }
    if (first) {
      this.data = obj;
      this.save();
      return path.map(function(x) {
        return x.split('.').join('\\.');
      }).join(".");
    } else {
      return obj;
    }
  };

  Database.prototype.get = function(path, separator) {
    var i, len, o, p;
    if (separator == null) {
      separator = '.';
    }
    this.load();
    path = this.parsePath(path, separator);
    o = this.data;
    for (i = 0, len = path.length; i < len; i++) {
      p = path[i];
      if (o[p] == null) {
        return null;
      }
      o = o[p];
    }
    return o;
  };

  Database.prototype.append = function(path, value, separator) {
    var o;
    o = this.get(path, separator);
    if (o == null) {
      o = [value];
    } else if (typeof o !== "array") {
      return null;
    } else {
      o.push(value);
    }
    return this.put(path, o, separator);
  };

  return Database;

})();

module.exports = {
  DBSerializable: DBSerializable,
  Database: Database,
  DatabaseSerializer: DatabaseSerializer,
  JSONSerializer: JSONSerializer,
  YAMLSerializer: YAMLSerializer,
  abstractClass: abstractClass,
  isImplementation: isImplementation
};
