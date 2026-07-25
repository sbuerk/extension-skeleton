# Architecture

How the code base is organised and which design rules apply to it. These are the
rules the skeleton itself follows — the shipped `Example` classes exist to
demonstrate them and are meant to be deleted once real code arrives.

| Page                                                  | Contents                                                                                                                                                |
|-------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| [Core version aware code](core-version-aware-code.md) | `Classes/` vs `Core13/` vs `Core14/`, container based selection of the right variant, the interface + abstract + implementation pattern.                |
| [Dependency injection](dependency-injection.md)       | Symfony DI attributes instead of `Services.yaml`, stateless services, private by default, `#[AsAlias]`, non-shared services.                            |
| [Class design](class-design.md)                       | `final readonly` and what it implies for hierarchies, method injection in abstract classes, data objects vs services, the two accepted PHPStan ignores. |

## The short version

- One code base serves TYPO3 v13 and v14. Version differences are resolved by
  **splitting classes**, not by conditionals in shared code.
- Services are **stateless** and wired with **attributes on the class**, never
  with service definitions in `Services.php` or a `Services.yaml`.
- Services are **private** unless something really has to fetch them from the
  container.
- Classes are **`final readonly`** unless a framework constraint prevents it.
- Data is not a service: models, entities, value objects and DTOs are created,
  not injected — and they carry **`#[Exclude]`** so directory based service
  registration does not pick them up.

## See also

- [Documentation index](../Index.md)
- [Testing](../testing/Index.md)
- [Quality gates](../development/quality-gates.md)
