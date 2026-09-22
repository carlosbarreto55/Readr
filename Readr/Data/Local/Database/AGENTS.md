# SwiftData rules

- `@Model` classes are persistence types. They never cross the **repository
  boundary**: a repository implementation may name them, and nothing above one
  may. Repositories map them to and from immutable domain `struct`s. See
  `architecture.md` §6.1.
- Domain models never import SwiftData; `@Model` types never appear in a
  repository protocol signature.
- Every schema change adds a new `VersionedSchema` and a `SchemaMigrationPlan`
  stage. Never mutate an existing version in place.
- **Destructive migration is forbidden.** Deleting the store on a schema mismatch
  destroys the user's library and reading progress.
- Every migration ships a test that opens a store written by the previous schema
  and asserts the data survived.
- Series and chapter identity is `(sourceID, url)`. Changing identity, primary
  keys, or relationship delete rules requires human approval.
