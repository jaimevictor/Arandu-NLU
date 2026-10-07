# Changelog

## 0.4.0

- Add contextual name/room set resolution, safe collective area shutdown and bounded dialogue choices.
- Add metric queries with unit validation, informative global/local lists and configurable low battery threshold.
- Associate personal devices and sensors using Home Assistant metadata and explicit bindings.
- Consume dynamic HA location observations with mandatory provider timestamps; never infer physical location from registered area.
- Add private-data-free version/protocol diagnostics and specific spoken failure reasons.
- Keep v1–v3 and `/health` compatible. Update the Python integration separately from the add-on.

## 0.3.2

- Publish only `addon/`; remove the stale duplicate store app.
- Preserve the public `ptbr_nlu` slug and repository identity.
- Synchronize Rust, add-on and integration versions; validate store structure
  and distribution changes in the standard gate.
- Include runtime license resources and provide separate reproducible ZIPs.
- Document store refresh, source image rebuild, manual integration update and rollback.

## 0.3.1

- Set the contextual implementation's release version to 0.3.1.
  The obsolete duplicate still advertised 0.2.0 until 0.3.2.
