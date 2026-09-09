-- Appended to select-capability.sql by the restricted reader. This is a point
-- lookup; requirement derivation is deliberately absent from this path.
IF OBJECT_ID('runtime.capability_preparation','U') IS NULL
    THROW 51000,'PREPARATION_SCHEMA_REQUIRED',1;
DECLARE @preparation_pk bigint;
SELECT @preparation_pk=preparation_pk FROM runtime.capability_preparation
WHERE estate_model_pk=@estate_model_pk AND capability_version_pk=@capability_version_pk
  AND scenario_version_pk=@scenario_version_pk AND target=@target
  AND recipe_digest=CONVERT(binary(32),SUBSTRING(JSON_VALUE(@input,'$.recipeDigest'),8,64),2)
  AND view_definition_digest=CONVERT(binary(32),SUBSTRING(@view_definition_digest,8,64),2);
IF @preparation_pk IS NULL
BEGIN
    IF EXISTS(SELECT 1 FROM runtime.capability_preparation WHERE capability_pk=@capability_pk AND target=@target)
        THROW 51000,'CAPABILITY_PREPARATION_STALE: run sfx capability prepare for the selected revision',1;
    THROW 51000,'CAPABILITY_PREPARATION_REQUIRED: run sfx capability prepare first',1;
END;
SELECT 'sha256:'+LOWER(CONVERT(varchar(64),payload_digest,2)) AS preparation_digest,
       payload_bytes,prepared_at
FROM runtime.capability_preparation WHERE preparation_pk=@preparation_pk;
