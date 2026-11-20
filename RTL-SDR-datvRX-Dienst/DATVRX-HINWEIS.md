# datvrx / dvbstool (HB9IIU DATVision) – Hinweis / Notice

**Deutsch:** Die Programme `datvrx` und `dvbstool` in den Ordnern `arm/` und `arm64/` (Raspberry Pi) sind **nicht von mir**. Sie sind Builds von
**DATVision von Daniel HB9IIU**, das den DVB-S/S2-Code von OnAir nutzt: <https://github.com/HB9IIU/DATVision> (Stand des Builds: Commit `d4d2d79`, 07.11.2026).
Dort liegen der Quelltext, die Dokumentation und die neuesten Versionen – bitte dort nachsehen und ihm danken. Lizenz: GNU GPL v3 (Text: `DATVRX-LICENSE-GPLv3.txt`).
Für den Raspberry Pi (ARMv7 mit NEON) habe ich einen kleinen Patch dazu gelegt: `arm/datvrx-armv7-neon.patch`; Bauanleitung: `arm/BAUEN.html`.
Die Programme werden unverändert „wie sie sind“ ohne Gewähr weitergegeben; Fragen zu `datvrx` selbst bitte an den Autor.

**English:** `datvrx` and `dvbstool` in `arm/` and `arm64/` (Raspberry Pi) are **not my work**. They are builds of **DATVision by Daniel HB9IIU**, which uses OnAir's
DVB-S/S2 code: <https://github.com/HB9IIU/DATVision> (build from commit `d4d2d79`, 2026-11-07). Source code, documentation and current versions are there.
License: GNU GPL v3 (`DATVRX-LICENSE-GPLv3.txt`). An ARMv7/NEON patch is included (`arm/datvrx-armv7-neon.patch`); build instructions: `arm/BAUEN.html`.
Provided as is, without warranty. If you can, please build `datvrx` yourself from the upstream source.
