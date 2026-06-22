# content/ - module content bundles

Each file here is a **content bundle** authored in the research chat and read by Cowork.
Cowork builds these into `index.html`; it does NOT author medical content itself.

A bundle (`<module>.md`) contains:
1. Module metadata - key/id, card title, card subtitle, registry text.
2. Questions - array of `{ id, section, label, type, options?, other?, min?, max?, placeholder? }`
   where type is one of: radio | checkbox | number | select | textarea.
3. Educational copy (optional) - intro/explanatory prose in the app's voice.
4. Results/spec logic (optional) - plain conditions on specific answers.
5. Citations - sources backing any factual claim.

See `_TEMPLATE.md` for a starting point.
