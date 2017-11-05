class AbstractFunction
    constructor = (@name) ->

    check = (cls) =>
        return cls.prototype[@name]?

class AbstractStaticFunction extends AbstractFunction
    check = (cls) =>
        return cls[@name]?

class AbstractionError extends Error
class AbstractClassError extends AbstractionError
class BadInheritanceError extends AbstractionError

absID = 0

abstractClass = (cls, onApply) ->
    class AbstractedClass extends cls
        constructor: ->
            throw new AbstractClassError('Can\'t instantiate abstract classes!')

        @apply: (otherClass) ->
            missingFuncs = []

            for k, v of cls
                if v instanceof AbstractFunction and (
                    !v.check(otherClass)
                )
                    missingFuncs.push(k)

                else if v instanceof AbstractStaticFunction
                    otherClass[k] = v

                else if v instanceof AbstractFunction
                    otherClass.prototype[k] = v

                else if v?
                    otherClass[k] = v
                    
            if missingFuncs.length > 0
                throw new BadInheritanceError("Following functions missing in the class definition for #{otherClass.name}, which inherits #{cls.name}: #{issingFuncs.join(' ')}")

            if onApply?
                onApply(otherClass)

            otherClass.__implements__ = @__absID__

            return otherClass

    for k, v of AbstractedClass
        if (not v?)
            AbstractedClass['@abs'][k] = v

            if k.startsWith('F_') and k.length > 2
                AbstractedClass[k.slice(2)] = new AbstractFunction(k.slice(2))
                delete AbstractedClass[k]

            else if k.startsWith('S_') and k.length > 2
                AbstractedClass[k.slice(2)] = new AbstractStaticFunction(k.slice(2))
                delete AbstractedClass[k]

    AbstractedClass.__absID__ = absID++

    if cls.__absInheritance__?
        AbstractedClass.__absInheritance__ = cls.__absInheritance__
        AbstractedClass.__absInheritance__.push(cls)

    else
        AbstractedClass.__absInheritance__ = [cls]

    AbstractedClass.name = "#{cls.name}_Abstracted"
    
    return AbstractedClass

isImplementation = (ins, cls) ->
    return ins.__implements__ == cls.__absID__

module.exports = {
    abstractClass: abstractClass
    isImplementation: isImplementation

    AbstractFunction: AbstractFunction
    AbstractClassError: AbstractClassError
    BadInheritanceError: BadInheritanceError
}