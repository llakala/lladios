{ warn }:
{
  modulePathWarning = warn ''
    at least one of your Adios modules used `.path` to specify an input's location in the tree. This
    has been deprecated in favor of `.from`.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#input-references
  '' null;

  mutatorTypeWarning = warn ''
    at least one of your adios modules used 'mutatorType' for an option. This has been deprecated, and 'type' now also
    applies to individual mutators as well. Options that use a different 'type' and 'mutatorType' should be refactored
    to use the same type.

    See the lladios changelog for rationale and a migration guide:
    https://github.com/llakala/lladios/blob/main/CHANGELOG.md#deprecated-mutatortype
  '' null;
}
