# localdb
is a Node.JS database library that allows for JSON and YAML (but you can easily extend the serializer options by implementing the abstract class `DatabaseSerializer` - see below for abstract classes!).

Its capabilities include serializing most objects, including primitive types, arrays and even objects that are serialized in a custom way (check the class `DBSerializable` for more!)

## API
### Databases
#### `DBSerializable`
**Objects of Custom Serialization**

This is an abstract class for which every implementing class must have the following functions:

* `toObject` 
**Function Scope:** instance - **Function Return Type:** `Object`

Returns any object (containing only objects, arrays or primitives) that represents this structure

* `fromObject` 
**Function Scope:** static - **Function Return Type:** declaring class

Returns the object with the unfrozen object, ready to be converted to an instance of the same class.

#### DatabaseSerializer
        

### Abstract Classes
