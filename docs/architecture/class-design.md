# Class design

## Abstract classes must not use constructor injection

The constructor of an abstract class is part of the API of every class
extending it. Adding a dependency to it changes the signature of all extending
classes — including those in other extensions — and therefore breaks them.

Abstract classes therefore use **method injection**: an `inject*()` method
carrying Symfony's `#[Required]` attribute. The constructor stays free for the
extending classes:

```php
use Symfony\Contracts\Service\Attribute\Required;

abstract readonly class AbstractExample implements ExampleInterface
{
    /** @phpstan-ignore property.uninitializedReadonly */
    protected Typo3Version $typo3Version;

    #[Required]
    public function injectTypo3Version(Typo3Version $typo3Version): void
    {
        /** @phpstan-ignore property.readOnlyAssignNotInConstructor */
        $this->typo3Version = $typo3Version;
    }
}
```

Concrete (`final`) classes have no such problem and use plain **constructor
injection**, ideally with promoted properties.

## Prefer `final readonly`

Classes should be `final readonly` whenever possible: `final` because services
are replaced through the container and not through inheritance, `readonly`
because a service must not change its state after construction.

`readonly` is not free of consequences for a class hierarchy, so the following
rules apply — all of them are enforced by PHP itself and verified against the
PHP versions this extension supports:

- A `readonly` class **cannot extend** a non-`readonly` class.
- A non-`readonly` class **cannot extend** a `readonly` class.
- An abstract class **may** be declared `abstract readonly`.

In other words, the whole hierarchy has to agree on it. Since abstract base
classes here use `inject*()` methods, they are declared `abstract readonly` so
that the extending classes can be `final readonly`:

| Abstract base class       | Extending classes      |
|---------------------------|------------------------|
| `abstract readonly class` | `final readonly class` |

## Data objects are not services

Models, entities, value objects and DTOs represent data, not behaviour. They are
created with `new`, by a factory or by the persistence layer, and never fetched
from the container.

### `#[Exclude]` is mandatory on all of them

`Configuration/Services.php` registers whole directories with `$services->load()`,
which does not distinguish a service from a data object. Every data object below
a loaded directory therefore needs Symfony's `#[Exclude]` attribute — **without
exception, Extbase models included**:

```php
use Symfony\Component\DependencyInjection\Attribute\Exclude;

#[Exclude]
final readonly class ExampleResult
{
    public function __construct(
        public string $identifier,
        public int $count,
    ) {}
}
```

The failure mode is worth knowing, because it explains why this is a rule rather
than a preference. A data object that is registered but never referenced is
removed again when the container is compiled, so **nothing breaks and nothing
warns** — the omission is invisible until someone type hints the data object
somewhere. Then the container fails to build, with an error pointing at the data
object rather than at the code that referenced it:

```
Cannot autowire service "Vendor\Extension\Dto\ExampleResult": argument
"$identifier" of method "__construct()" is type-hinted "string", you should
configure its value explicitly.
```

Adding the attribute when the class is written costs nothing; finding this later
costs an afternoon.

### Immutability, and where Extbase differs

Keep data objects immutable where the framework allows it — `final readonly`
with promoted constructor properties, named arguments at the call site — and
give them explicit types rather than untyped arrays.

Extbase domain models are the exception, and **only to this part of the rule**:
Extbase requires mutable properties and a no-argument constructor, because the
data mapper assigns properties by reflection on an instance it creates without
calling the constructor. So an Extbase model is neither `readonly` nor
constructor-injected — but it is still a data object, and it still carries
`#[Exclude]`. The skeleton's own
[`Greeting`](../../Tests/Functional/Fixtures/Extensions/example-fixture/Classes/Domain/Model/Greeting.php)
model shows both.

See [Dependency injection](dependency-injection.md#rules).

## The two PHPStan ignores on injected readonly properties

PHP allows a readonly property to be initialized by **any** method of its
declaring class, not only the constructor — an `inject*()` method therefore
initializes it perfectly legally, and PHP still rejects every later write.
PHPStan is stricter and insists on the constructor, which produces exactly two
findings on such a property:

| Identifier                                | Reported on              |
|-------------------------------------------|--------------------------|
| `property.uninitializedReadonly`          | the property declaration |
| `property.readOnlyAssignNotInConstructor` | the assignment           |

Both are ignored by their identifier, as shown in the example above. **This is
required and absolutely fine here**: it is the only way to combine the two rules
this repository holds — a constructor kept free for extending classes, and a
`readonly` hierarchy — and PHP itself still guarantees the immutability that
`readonly` promises. The pattern is verified by the skeleton's own
[`AbstractExample`](../../Classes/Example/AbstractExample.php).

Do **not** take this as a licence to silence PHPStan elsewhere. The ignores are
acceptable **only** for a property that is

1. declared in an `abstract readonly` class,
2. assigned exactly once, in its own `#[Required]`-annotated `inject*()` method,
3. never written anywhere else.

Anything beyond that is a misuse: ignore the finding nowhere else, never widen
an ignore to a whole file or class, and never use it to work around a genuine
mutability problem. Prefer fixing the finding — and if a service really needs
to change state after construction, it is not a service (see
[Dependency injection](dependency-injection.md)).

## See also

- [Dependency injection](dependency-injection.md)
- [Core version aware code](core-version-aware-code.md)
- [Quality gates](../development/quality-gates.md)
