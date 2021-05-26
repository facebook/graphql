# Glossary RFC

The GraphQL spec uses a lot of terminology, some of this terminology is
introduced implicitly, some is defined explicitly, but either way finding the
definition when you read a term in the spec can be challenging.

To address these challenges, we propose adding a glossary to the GraphQL spec.
This glossary will be in the form of an additional appendix at the end of the
GraphQL spec.

We may or may not enhance `spec-md` with glossary-specific features (for example
linking to definitions where terms are used, or displaying the definition on
hover in a tooltip). This is currently seen as a separate effort since having a
glossary is useful in itself, so we should concentrate for now on the glossary
definitions only.

This RFC is composed of this file (`rfcs/glossary/README.md`) which explains the
thought behind the glossary RFC, and the glossary file itself
([`rfcs/glossary/Appendix C -- Glossary.md`](./Appendix%20C%20--%20Glossary.md))
which should be suitable for moving directly into the `spec/` folder in order to
add the glossary to the spec.

The glossary is not yet complete, and PRs adding definitions to it (in
alphabetical order) are welcome.
