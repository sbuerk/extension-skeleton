# Dependency injection

Services are wired with **Symfony dependency injection attributes on the
classes themselves**, not with `Configuration/Services.yaml` and not with
service definitions in `Configuration/Services.php`. That file only sets the
defaults and the directories to load; everything else belongs on the class.

The defaults are `autowire`, `autoconfigure` and `private`:

```php
$services->defaults()
    ->autowire()
    ->autoconfigure()
    ->private();
```

The second job of [`Configuration/Services.php`](../../Configuration/Services.php)
is selecting the core version aware directory to register — see
[Core version aware code](core-version-aware-code.md#how-the-right-variant-is-selected).

## Rules

- **Dependency injection is for stateless services only.** A service must not
  carry request, user or record state between calls. Models, entities, value
  objects, DTOs and anything else representing data are **not** services and
  are never fetched from the container — create them with `new`, a factory or
  let the persistence layer produce them.
- **Data objects carry `#[Exclude]`.** `$services->load()` registers a whole
  directory and cannot tell a service from a data object, so every data object
  below a loaded directory has to opt out — Extbase models included. Omitting it
  breaks nothing until someone type hints the data object, and the error then
  points at the wrong class:
  → [`#[Exclude]` is mandatory on all of them](class-design.md#exclude-is-mandatory-on-all-of-them)
- **Services are private by default.** Only publish what really has to be
  fetched from the container — the TYPO3 core does that for API entry points
  and functional tests need it. Publish explicitly and deliberately:

  ```php
  #[Autoconfigure(public: true)]
  final readonly class Dummy
  {
  }
  ```

- **Register a default implementation of an interface with `#[AsAlias]`**, so
  consumers depend on the interface. This is what makes the core version aware
  implementations interchangeable.
- **Configurable services are possible, but must be non-shared.** A service
  that is configured after construction — a "prototype" that a caller
  parameterizes — must not be shared, otherwise the configuration of one caller
  leaks into all others:

  ```php
  #[Autoconfigure(shared: false)]
  final class ConfigurableThing
  {
  }
  ```

  Every retrieval from the container then returns a fresh instance. Prefer a
  stateless service with parameters on the method, and reach for a non-shared
  service only when the configuration really cannot be passed per call.
- **Do not inject the container** (`ContainerInterface`) to look services up at
  runtime. Inject what is needed, or a service locator / iterator built from a
  tag when the set of implementations is open.

## Attributes in use

| Attribute                                 | Purpose                                                                                                                        |
|-------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| `#[Autoconfigure]`                        | Publish a service, mark it non-shared, add tags.                                                                               |
| `#[AsAlias]`                              | Register the default implementation of an interface.                                                                           |
| `#[Autowire]`                             | Pin a specific service, parameter or expression to one argument.                                                               |
| `#[AsTaggedItem]` / `#[AutowireIterator]` | Tagged collections.                                                                                                            |
| `#[Exclude]`                              | Keep a class out of the container, see [Data objects](class-design.md#data-objects-are-not-services).                          |
| `#[Required]`                             | Method injection in abstract classes, see [Class design](class-design.md#abstract-classes-must-not-use-constructor-injection). |

## See also

- [Class design](class-design.md)
- [Core version aware code](core-version-aware-code.md)
