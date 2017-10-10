# localdb
is a Node.JS database library that allows for JSON and YAML (but you can easily extend the serializer options by implementing the abstract class `DatabaseSerializer` - [see below for abstract classes!](#abstract-classes)).

Its capabilities include serializing most objects, including primitive types, arrays and even objects that are serialized in a custom way (check the class `DBSerializable` for more!)

An example of its usage:

    $ node
    > var { YAMLSerializer } = require('./index.js')
    undefined
    > YAMLSerializer
    { [Function: YAMLSerializer] database: [Function] }
    > var db = YAMLSerializer.database('test.yml')
    undefined
    > db.put("test.2.thanks", {"Hello": "World!"})
    'test.2.thanks'
    > db.get("test.2.thanks.hello") // Hey, path strings are case-sensitive!
    null
    > db.get("test.2.thanks.Hello") // Now it's right. :)
    'World!'
    > db.get("test.2.thanks")
    { Hello: 'World!' }

This chain of commands results in a `test.yml` file with the following contents:

    spec:
        serialization: null
        type: object
        primitive: false
    obj:
        test:
            spec:
                serialization: null
                type: object
                primitive: false
            obj:
                '2':
                    spec:
                        serialization: null
                        type: object
                        primitive: false
                    obj:
                        thanks:
                            spec:
                                serialization: null
                                type: object
                                primitive: false
                            obj:
                                Hello:
                                    spec:
                                        serialization: null
                                        type: string
                                        primitive: true
                                    obj: World!

In case you don't require advanced specification structures for accurately flexible representations, **please** don't use this! It'll make your file way larger and isn't suitable for large files.

# API
## Databases

### `Database(String filename, [Class<? implements DBSerializable> or DBSerializable] serializer)`
**The Spotlight of this Library**

This is a concrete class (*i.e.* non-abstract) which has common database functions like `put`, `get` and `save`; those functions automatically sync it with a filename given in the constructor (or in the serializer's ). Extending it can be made by inheriting it (using CoffeeScript or maybe ES6).

This class has the following functions:

* `put(String path, Object value)`

**Function Scope:** instance - **Function Return Type:** `String`

Puts a value object of any supported kind in the path specified (which is basically a path that includes keys separated by a `.` dot) of this database.

Returns `path` for further concatenation with subpathes etc.

**Does NOT support `..`!**

* `get(String path)`

**Function Scope:** instance - **Function Return Type:** `[Object or null]`

Gets an object at the specified path of this database, or `null` if none was found.
Pathes are formed like the ones in the call to `put`.

* `serialize(Object in)`

**Function Scope:** instance - **Function Return Type:** `String`

Serializes an object to a string as if it were part of the database.

* `objectFrom(Object in)`

**Function Scope:** instance - **Function Return Type:** `Object` (serialized)

Returns an object containing spec that can be deserialized using `unfreeze`. All objects returned by `objectFrom` must be composed by primitive types, arrays and objects only; but they must represent accurately the in object when passed to `unfreeze`.

* `unfreeze(Object in)`

**Function Scope:** instance - **Function Return Type:** `Object` (deserialized)

The antonym of `objectFrom`.

### `DBSerializable()`
**Objects of Custom Serialization**

This is an abstract class for which implementing classes contain information on how custom objects should be transformed into and obtained from serializable  Objects.
Every implementing class must have the following functions:

* `toObject()` 

**Function Scope:** instance - **Function Return Type:** `Object`

Returns any object (containing only objects, arrays or primitives) that represents this structure

* `fromObject(Object from)` 

**Function Scope:** static - **Function Return Type:** declaring class

Returns the object with the unfrozen object, ready to be converted to an instance of the same class.

### `DatabaseSerialize()`

**Serialization into Other Languages**

This is an abstract class for which implementing classes can parse and stringify basic object kinds into basic (or not) languages, such as for example INI or NBT.
Every implementing class must have the following functions:

* `serialize(String data)`

**Function Scope:** instance - **Function Return Type:** `String`

Returns a String representing the data *accurately*.

* `deserialize(Object data)`

**Function Scope:** instance - **Function Return Type:** `Object`

Returns an Object containing the data represented by the string.

#### Additionally, all objects implementing DatabaseSerializer have the following default functions:

* `database(String filename)`

**Function Scope:** static - **Function Return Type:** `Database`

Returns a database with the serializer set automatically to the Serializer it is called on. A filename must still be provided.

## Abstract Classes

Abstract classes are classes that have unimplemented methods and thus for security can't be instantiated; you need to set it to an implemented version of it using its `apply` function. Their main usage is for template code which can serve as the bare bones for future classes that have the same (or similar) concept or usage, but different methodology.

These are based in Java interfaces.

### Functions
* `abstractClass(Class other, optional Function onApply(Class s))`

**Function Scope:** global - **Function Return Type:** `AbstractClass`

Returns an abstracted version of this class, which has an `apply(Class other)` static function that returns a version of `other` implementing this class (which is necessary to make it an implementation of this class).

#### Rules for abstract classes:
* All abstract functions must be `null`, static, and their name must be prefixed by either `F_` for instance functions or `S_` for static ones.
* Every other static property (functions or not) are inherited if their value is not `null` or `undefined`.
* Since abstract classes can never be instantiated, no instance function is inherited.

* `isImplementation(Class other, Class abstractClass)`

**Function Scope:** global - **Function Return Type:** `boolean`

Returns whether `other` implements `abstractClass`.
