1. entity/schema change plus a generated migration;
2. DTOs (`class-validator`) for input, and the response shape;
3. service: the business logic, owns the repository/ORM;
4. controller (or resolver), registered in the feature module;
5. tests: a unit spec for the service, an e2e spec for the route.
