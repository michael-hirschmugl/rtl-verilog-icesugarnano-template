# IceSugarNano • Windows Template with OSS CAD Suite

This repository is a **Windows-first template** for iCE40 FPGA projects (IceSugarNano, LP1K/CM36) using the **OSS CAD Suite**. It covers the **end-to-end flow**:

* **RTL/Verilog** development
    
* **Simulation** with Icarus Verilog (`iverilog` + `vvp`) and **VCD** waveforms
    
* **Synthesis** (Yosys) → **Place & Route** (nextpnr-ice40) → **Bitstream** (icepack)
    
* **Board programming** (icesprog)
    
* **Documentation** (Yosys `show`, Graphviz `dot`, netlistsvg)
    
* **Timing analysis** (icetime)
    
* **GUI P&R** (nextpnr `--gui`)
    

Everything is **PowerShell-based** and intentionally **Windows-focused**.

* * *

## Table of Contents

* [Prerequisites (Windows)](#prerequisites-windows)
    
* [Directory Layout](#directory-layout)
    
* [File Explanations](#file-explanations)
    
* [The Build Flow at a Glance](#the-build-flow-at-a-glance)
    
* [Scripts (PowerShell)](#scripts-powershell)
    
    * [`build.ps1` – Synthesis → P&R → Bitstream → Flash](#buildps1--synthesis--pr--bitstream--flash)
        
    * [`sim.ps1` – Simulation + VCD](#simps1--simulation--vcd)
        
    * [`doc.ps1` – Documentation Artifacts (Schematic/Block/Timing)](#docps1--documentation-artifacts-schematicblocktiming)
        
    * [`pnr_gui.ps1` – nextpnr with GUI](#pnr_guips1--nextpnr-with-gui)
        
* [Common Tasks (Recipes)](#common-tasks-recipes)
    
* [Pin Constraints (PCF)](#pin-constraints-pcf)
    
* [Troubleshooting](#troubleshooting)
    
* [Repository Hygiene Tips](#repository-hygiene-tips)
    
* [Next Steps](#next-steps)
    
* [License Notice](#license-notice)
    

* * *

## Prerequisites (Windows)

### 1) OSS CAD Suite (Windows Release)

* Extract to: `C:\oss-cad-suite`
    
* Load for each PowerShell session:
    
    ```powershell
    . C:\oss-cad-suite\environment.ps1
    ```
    
    This puts `yosys`, `nextpnr-ice40`, `icepack`, `icetime`, `icesprog`, `iverilog`, `vvp` and (usually) `gtkwave` on your `PATH`.
    

### 2) Graphviz `dot` (for schematic SVGs)

* Install (pick one):
    
    ```powershell
    winget install Graphviz.Graphviz
    # or
    choco install graphviz
    ```
    
* Verify:
    
    ```powershell
    dot -V
    ```
    
* If `dot` is not found, add the path once:
    
    ```powershell
    setx PATH "$env:PATH;C:\Program Files\Graphviz\bin"
    ```
    

### 3) (Optional) Node.js + netlistsvg (pretty block diagrams)

* Install Node.js (LTS), then:
    
    ```powershell
    npm i -g netlistsvg
    ```
    
* Or without global install:
    
    ```powershell
    npx netlistsvg --help
    ```
    

### 4) Allow running PowerShell scripts

* If needed:
    
    ```powershell
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
    ```
    
* Or unblock files:
    
    ```powershell
    Unblock-File .\scripts\*.ps1
    ```
    

### 5) Editor Encoding

* Save files as **UTF-8 (without BOM)**.
    
* Avoid umlauts/special symbols inside script **string literals** (comments are fine).
    

* * *

## Directory Layout

```
<repo-root>/
├─ src/                    # RTL sources (Verilog)
│  ├─ top.v                # Top-level module (entry point)
│  └─ ...                  # additional modules
├─ tb/                     # Testbenches (simulation-only)
│  └─ tb_top.v
├─ constraints/            # Board pins & I/O constraints
│  └─ io.pcf               # PCF for IceSugarNano (LP1K/CM36)
├─ scripts/                # Windows PowerShell tools
│  ├─ build.ps1            # Synthesis -> P&R -> Bitstream -> Flash
│  ├─ sim.ps1              # Simulation (iverilog/vvp) + VCD
│  ├─ doc.ps1              # Yosys show + netlistsvg + icetime + icebox_vlog
│  └─ pnr_gui.ps1          # nextpnr-ice40 with GUI
├─ build/                  # *generated* artifacts (JSON/ASC/BIN/VCD)
└─ docs/                   # *generated* documentation (SVG/Reports)
```

* * *

## File Explanations

### `src/top.v`

* **Top-level module** of the design (e.g., LED blinker, UART top, etc.).
    
* Instantiates submodules (also placed in `src/`).
    

### `tb/tb_top.v`

* **Testbench** for simulation: generates clock, drives stimuli, writes **VCD**.
    
* Example boilerplate:
    
    ```verilog
    initial begin
      $dumpfile("build/tb_top.vcd");
      $dumpvars(0, tb_top);
      #50_000_000; // simulation time (ps/ns)
      $finish;
    end
    ```
    

### `constraints/io.pcf`

* **Pin assignments** for the board (e.g., `set_io clk D1`, `set_io LED B6`).
    
* Must match your **IceSugarNano revision**.
    
* Comment out unused pins initially (prevents “unmatched constraint” warnings).
    

### `scripts/*.ps1`

* **Windows scripts** to automate the flow (see the Scripts section below).
    

### `build/` (generated)

* `top.json` — Yosys netlist (tech-mapped for iCE40).
    
* `top.asc` — nextpnr placement/routing (ASCII).
    
* `top.bin` — final bitstream for FPGA/Flash.
    
* `sim.vvp` — simulation binary from `iverilog`.
    
* `tb_top.vcd` — simulation waveform.
    

### `docs/` (generated)

* `top_schem.svg` — **schematic** from Yosys `show` (via Graphviz).
    
* `top_block.svg` — **block diagram** from netlistsvg (if installed).
    
* `timing.rpt` — **timing report** from `icetime`.
    
* `top_from_bitstream.v` — Verilog netlist reconstructed from `.asc` (icebox_vlog).
    

* * *

## The Build Flow at a Glance

```
Verilog (src/*.v)
      │
      ▼
Yosys synth_ice40  ────────────────► build/top.json
      │
      ▼
nextpnr-ice40 (+ io.pcf) ─────────► build/top.asc
      │
      ▼
icepack  ──────────────────────────► build/top.bin
      │
      ├─► icesprog -S top.bin  (SRAM: fast test, volatile)
      └─► icesprog -w top.bin  (Flash: persistent)
```

Documentation/analysis in parallel:

* `yosys show` + Graphviz → `docs/top_schem.svg`
    
* `netlistsvg` → `docs/top_block.svg`
    
* `icetime` → `docs/timing.rpt`
    
* `icebox_vlog` → `docs/top_from_bitstream.v`
    

* * *

## Scripts (PowerShell)

> All scripts internally source **`C:\oss-cad-suite\environment.ps1`**.  
> Run them from the repository root (or adjust paths).

### `build.ps1` – Synthesis → P&R → Bitstream → Flash

**What it does:** Builds the bitstream and programs either **SRAM** (fast, volatile) or **Flash** (persistent).

**Parameters (common):**

* `-Top <name>` – top module (default: `top`, file: `src/top.v`)
    
* `-Pcf <path>` – PCF file (default: `.\constraints\io.pcf`)
    
* `-Flash` – write **SPI Flash** instead of loading SRAM (`icesprog -w`)
    
* `-FreqMHz <int>` – target hint for `nextpnr --freq` (affects P&R, does **not** change the real clock)
    
* `-Seed <int>` – placer seed for reproducible placement
    

**Examples:**

```powershell
.\scripts\build.ps1                   # builds .bin, loads to SRAM (icesprog -S)
.\scripts\build.ps1 -Flash           # builds .bin, writes to Flash (icesprog -w)
.\scripts\build.ps1 -FreqMHz 24 -Seed 42
```

**Produces:**

* `build/top.json`, `build/top.asc`, `build/top.bin`
    
* Programs the board via `icesprog` (SRAM or Flash)
    

**Why it’s useful:** One command for **change → test** loops. SRAM load is faster and saves Flash wear during development.

* * *

### `sim.ps1` – Simulation + VCD

**What it does:** Compiles TB + RTL with `iverilog`, runs with `vvp`, finds the newest **VCD**, and optionally opens **gtkwave**.

**Parameters:**

* `-Top <name>` – top module (default: `top`)
    
* `-TbFile <file>` – testbench file (default: `tb_top.v`)
    
* `-ExtraSrc <array>` – extra RTL files **only** if not included via `` `include ``
    
* `-OpenWave` – automatically open VCD in gtkwave
    
* `-EnvScript <path>` – OSS env script (default: `C:\oss-cad-suite\environment.ps1`)
    

**Examples:**

```powershell
.\scripts\sim.ps1 -OpenWave
.\scripts\sim.ps1 -ExtraSrc .\src\uart_tx.v
```

**Produces:**

* `build/sim.vvp`, `build/tb_top.vcd`
    

**Why it’s useful:** Simulation catches **logic errors early**; VCD is your **ground truth** for signal behavior.

* * *

### `doc.ps1` – Documentation Artifacts (Schematic/Block/Timing)

**What it does:** Generates a **schematic SVG** (Yosys `show` + Graphviz `dot`), optionally a **block SVG** (netlistsvg), then runs **synth_ice40**, **nextpnr**, **icetime**, **icebox_vlog**, and prints a **timing digest**.

**Parameters:**

* `-Top <name>` – top module (default: `top`)
    

**Example:**

```powershell
.\scripts\doc.ps1
```

**Produces:**

* `docs/top_schem.svg` (Graphviz)
    
* `docs/top_block.svg` (if netlistsvg is available)
    
* `docs/timing.rpt` (icetime)
    
* `docs/top_from_bitstream.v` (icebox_vlog)
    
* plus `build/top.json`, `build/top.asc` as by-products
    

**Why it’s useful:** Project documentation is **auto-generated**: schematic image, block diagram, timing report — ready to commit.

* * *

### `pnr_gui.ps1` – nextpnr with GUI

**What it does:** Launches **nextpnr-ice40** with `--gui`. Optionally builds the JSON netlist if missing.

**Parameters:**

* `-Top <name>` – top module (default: `top`)
    
* `-SynthesizeIfMissing` – build JSON if missing
    
* `-ForceSynthesize` – always rebuild JSON
    
* `-FreqMHz <int>` – pass `--freq` to nextpnr
    
* `-Seed <int>` – placer seed
    
* `-Device` / `-Package` – defaults: `lp1k` / `cm36`
    
* `-Pcf <path>` – default: `

---

German Version:

# IceSugarNano • Windows-Template mit OSS CAD Suite

Dieses Repo ist ein **Windows-Template** für iCE40-FPGA-Projekte (IceSugarNano, LP1K/CM36) mit der **OSS CAD Suite**. Es deckt den **kompletten Flow** ab:

* **RTL/Verilog** entwickeln
    
* **Simulation** mit Icarus Verilog (iverilog + vvp) und **VCD**
    
* **Synthesis** (Yosys) → **Place & Route** (nextpnr-ice40) → **Bitstream** (icepack)
    
* **Flashen** des Boards (icesprog)
    
* **Dokumentation** (Yosys show, Graphviz dot, netlistsvg)
    
* **Timing-Analyse** (icetime)
    
* **GUI-P&R** (nextpnr --gui)
    

Alles ist **PowerShell-basiert** und absichtlich **Windows-fokussiert**.

* * *

## Inhalt

* [Voraussetzungen (Windows)](#voraussetzungen-windows)
    
* [Ordnerstruktur](#ordnerstruktur)
    
* [Dateien erklärt](#dateien-erkl%C3%A4rt)
    
* [Der Build-Flow in einem Bild](#der-build-flow-in-einem-bild)
    
* [Skripte (PowerShell)](#skripte-powershell)
    
    * [build.ps1 – Synthese → P&R → Bitstream → Flash](#buildps1--synthese--pr--bitstream--flash)
        
    * [sim.ps1 – Simulation + VCD](#simps1--simulation--vcd)
        
    * [doc.ps1 – Doku-Artefakte (Schematic/Block/Timing)](#docps1--doku-artefakte-schematicblocktiming)
        
    * [pnr_gui.ps1 – nextpnr mit GUI](#pnr_guips1--nextpnr-mit-gui)
        
* [Häufige Aufgaben (Kochrezepte)](#h%C3%A4ufige-aufgaben-kochrezepte)
    
* [Pin-Constraints (PCF)](#pin-constraints-pcf)
    
* [Troubleshooting](#troubleshooting)
    
* [Tipps für saubere Repos](#tipps-f%C3%BCr-saubere-repos)
    
* [Weiterdenken](#weiterdenken)
    
* [Lizenzhinweis](#lizenzhinweis)
    

* * *

## Voraussetzungen (Windows)

### 1) OSS CAD Suite (Windows Release)

* Entpackt unter: C:\oss-cad-suite
    
* In jeder PowerShell-Session laden:
    
    
powershell
    . C:\oss-cad-suite\environment.ps1

    
    Dadurch landen yosys, nextpnr-ice40, icepack, icetime, icesprog, iverilog, vvp, (meist auch) gtkwave im PATH.
    

### 2) Graphviz dot (für Schematic-SVGs)

* Installation (eine Option genügt):
    
    
powershell
    winget install Graphviz.Graphviz
    # oder
    choco install graphviz

    
* Prüfen:
    
    
powershell
    dot -V

    
* Falls dot nicht gefunden wird, den Pfad einmalig ergänzen:
    
    
powershell
    setx PATH "$env:PATH;C:\Program Files\Graphviz\bin"

    

### 3) (Optional) Node.js + netlistsvg (hübsche Blockdiagramme)

* Installiere Node.js (LTS) und anschließend:
    
    
powershell
    npm i -g netlistsvg

    
* Oder ohne globale Installation:
    
    
powershell
    npx netlistsvg --help

    

### 4) PowerShell-Skripte ausführen

* Ggf. Richtlinie setzen:
    
    
powershell
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

    
* Oder einzelne Skripte entsperren:
    
    
powershell
    Unblock-File .\scripts\*.ps1

    

### 5) Editor-Encoding

* Dateien als **UTF-8 (ohne BOM)** speichern.
    
* In Skript-Strings möglichst **keine Umlaute/Sonderzeichen** verwenden.
    

* * *

## Ordnerstruktur


<repo-root>/
├─ src/                    # RTL-Quellcode (Verilog)
│  ├─ top.v                # Top-Level-Modul (Einstiegspunkt)
│  └─ ...                  # weitere Module
├─ tb/                     # Testbenches (nur Simulation)
│  └─ tb_top.v
├─ constraints/            # Board-Pins & I/O-Constraints
│  └─ io.pcf               # PCF für IceSugarNano (LP1K/CM36)
├─ scripts/                # Windows PowerShell Tools
│  ├─ build.ps1            # Synthese -> P&R -> Bitstream -> Flash
│  ├─ sim.ps1              # Simulation (iverilog/vvp) + VCD
│  ├─ doc.ps1              # Yosys show + netlistsvg + icetime + icebox_vlog
│  └─ pnr_gui.ps1          # nextpnr-ice40 mit GUI
├─ build/                  # *generierte* Artefakte (JSON/ASC/BIN/VCD)
└─ docs/                   # *generierte* Dokumentation (SVG/Reports)


* * *

## Dateien erklärt

### src/top.v

* **Top-Level-Modul** des Designs (z. B. LED-Blinker, UART-Top etc.).
    
* Instanziiert ggf. Untermodule (liegen ebenfalls in src/).
    

### tb/tb_top.v

* **Testbench** für Simulation: erzeugt Takt, stimuliert Signale, schreibt **VCD**.
    
* Beispiel-Boilerplate:
    
    
verilog
    initial begin
      $dumpfile("build/tb_top.vcd");
      $dumpvars(0, tb_top);
      #50_000_000; // Simulationsdauer in ps/ns
      $finish;
    end

    

### constraints/io.pcf

* **Pin-Zuweisungen** fürs Board (z. B. set_io clk D1, set_io LED B6).
    
* Muss zur **IceSugarNano-Revision** passen.
    
* Nicht verwendete Pins zunächst auskommentieren (sonst „unmatched constraint“-Warnung).
    

### scripts/*.ps1

* **Windows-Skripte** zum Automatisieren des Flows (siehe Abschnitt „Skripte“).
    

### build/ (generiert)

* top.json — Yosys-Netzliste (tech-mapped für iCE40).
    
* top.asc — nextpnr-Platzierung/Routing (ASCII).
    
* top.bin — Bitstream für den FPGA/Flash.
    
* sim.vvp — Simulations-Binary von iverilog.
    
* tb_top.vcd — Wellenform der Simulation.
    

### docs/ (generiert)

* top_schem.svg — **Schematic** aus Yosys show (Graphviz).
    
* top_block.svg — **Blockdiagramm** aus netlistsvg (falls installiert).
    
* timing.rpt — **Timing-Report** aus icetime.
    
* top_from_bitstream.v — Verilog-Netzliste zurückgewonnen aus .asc (icebox_vlog).
    

* * *

## Der Build-Flow in einem Bild


Verilog (src/*.v)
      │
      ▼
Yosys synth_ice40  ────────────────► build/top.json
      │
      ▼
nextpnr-ice40 (+ io.pcf) ─────────► build/top.asc
      │
      ▼
icepack  ──────────────────────────► build/top.bin
      │
      ├─► icesprog -S top.bin  (SRAM: schneller Test, flüchtig)
      └─► icesprog -w top.bin  (Flash: persistent)


Doku/Analyse parallel:

* yosys show + Graphviz → docs/top_schem.svg
    
* netlistsvg → docs/top_block.svg
    
* icetime → docs/timing.rpt
    
* icebox_vlog → docs/top_from_bitstream.v
    

* * *

## Skripte (PowerShell)

> Alle Skripte laden intern **C:\oss-cad-suite\environment.ps1**.  
> Aufruf jeweils aus dem Repo-Root (oder Pfade anpassen).

### build.ps1 – Synthese → P&R → Bitstream → Flash

**Aufgabe:** Baut den Bitstream und programmiert wahlweise **SRAM** (schnell, flüchtig) oder **Flash** (persistent).

**Parameter (typisch):**

* -Top <name> – Top-Modul (Default: top, Datei: src/top.v)
    
* -Pcf <pfad> – PCF-Datei (Default: .\constraints\io.pcf)
    
* -Flash – statt SRAM in die **SPI-Flash** schreiben (icesprog -w)
    
* -FreqMHz <int> – Zielvorgabe für nextpnr --freq (beeinflusst P&R, ändert nicht den echten Takt)
    
* -Seed <int> – Placer-Seed für reproduzierbare Platzierung
    

**Beispiel:**


powershell
.\scripts\build.ps1                   # baut .bin, lädt in SRAM (icesprog -S)
.\scripts\build.ps1 -Flash           # baut .bin, schreibt in Flash (icesprog -w)
.\scripts\build.ps1 -FreqMHz 24 -Seed 42


**Erzeugt:**

* build/top.json, build/top.asc, build/top.bin
    
* Programmierung via icesprog (SRAM oder Flash)
    

**Warum hilfreich?**  
Ein Kommando für **„ändern → testen“**. SRAM-Load schont die Flash und ist schneller bei iterativer Entwicklung.

* * *

### sim.ps1 – Simulation + VCD

**Aufgabe:** Kompiliert Testbench + RTL mit iverilog, führt sie mit vvp aus, findet die neueste **VCD** und öffnet optional **gtkwave**.

**Parameter:**

* -Top <name> – Top-Modul (Default: top)
    
* -TbFile <datei> – Testbench (Default: tb_top.v)
    
* -ExtraSrc <array> – zusätzliche RTL-Dateien, **nur** wenn nicht per ` include ` eingebunden
    
* -OpenWave – VCD automatisch in gtkwave öffnen
    
* -EnvScript <pfad> – Pfad zur OSS-Umgebung (Default: C:\oss-cad-suite\environment.ps1)
    

**Beispiel:**


powershell
.\scripts\sim.ps1 -OpenWave
.\scripts\sim.ps1 -ExtraSrc .\src\uart_tx.v


**Erzeugt:**

* build/sim.vvp, build/tb_top.vcd
    

**Warum hilfreich?**  
Simulation fängt **Logikfehler früh** ab, VCD ist die **Wahrheitsfolie** für Signalverläufe.

* * *

### doc.ps1 – Doku-Artefakte (Schematic/Block/Timing)

**Aufgabe:** Generiert **Schematic-SVG** (Yosys show + Graphviz dot), optional **Block-SVG** (netlistsvg), fährt **synth_ice40**, **nextpnr**, **icetime**, **icebox_vlog** und schreibt eine **Timing-Kurzfassung** in die Konsole.

**Parameter:**

* -Top <name> – Top-Modul (Default: top)
    

**Beispiel:**


powershell
.\scripts\doc.ps1


**Erzeugt:**

* docs/top_schem.svg (Graphviz)
    
* docs/top_block.svg (falls netlistsvg vorhanden)
    
* docs/timing.rpt (icetime)
    
* docs/top_from_bitstream.v (icebox_vlog)
    
* sowie build/top.json, build/top.asc als Nebenprodukte
    

**Warum hilfreich?**  
Projektdoku entsteht **automatisch**: Schaltplanbild, Blockdiagramm, Timing-Report – direkt commit-bar fürs Repo.

* * *

### pnr_gui.ps1 – nextpnr mit GUI

**Aufgabe:** Startet **nextpnr-ice40** mit --gui. Baut optional die JSON-Netzliste, falls sie fehlt.

**Parameter:**

* -Top <name> – Top-Modul (Default: top)
    
* -SynthesizeIfMissing – JSON bauen, falls nicht vorhanden
    
* -ForceSynthesize – JSON immer neu bauen
    
* -FreqMHz <int> – --freq an nextpnr
    
* -Seed <int> – Placer-Seed
    
* -Device / -Package – Default: lp1k / cm36
    
* -Pcf <pfad> – Default: .\constraints\io.pcf
    

**Beispiel:**


powershell
.\scripts\pnr_gui.ps1 -SynthesizeIfMissing
.\scripts\pnr_gui.ps1 -ForceSynthesize -FreqMHz 24 -Seed 7


**Erzeugt:**

* build/top.asc (wenn die GUI bis zum Ende läuft/speichert)
    

**Warum hilfreich?**  
**Interaktive** Ansicht von Platzierung/Netzen/IOs. Praktisch für **Pin-Checks** und Layout-Verständnis.

* * *

## Häufige Aufgaben (Kochrezepte)

**Bitstream bauen & in SRAM laden (schneller Test)**


powershell
.\scripts\build.ps1


**Bitstream bauen & in Flash schreiben (persistente Konfiguration)**


powershell
.\scripts\build.ps1 -Flash


**Simulation mit Wellenform öffnen**


powershell
.\scripts\sim.ps1 -OpenWave


**Dokumentation erzeugen (SVG/Timing/Verilog-Rückführung)**


powershell
.\scripts\doc.ps1


**nextpnr GUI**


powershell
.\scripts\pnr_gui.ps1 -SynthesizeIfMissing


* * *

## Pin-Constraints (PCF)

* Syntax:
    
    
set_io <portname> <pin>

    
* Beispiel IceSugarNano (Platzhalter ersetzen):
    
    
set_io clk D1
    set_io LED B6
    # set_io TX  <pin>   # auskommentieren, wenn Port im RTL fehlt
    # set_io RX  <pin>

    
* **Tipp:** Nicht verwendete Pins **auskommentieren**, bis die Ports im RTL existieren → verhindert „unmatched constraint“-Warnungen.
    

* * *

## Troubleshooting

**„dot is not recognized …“**

* Neue PowerShell öffnen (PATH aktualisiert sich) oder:
    
    
powershell
    setx PATH "$env:PATH;C:\Program Files\Graphviz\bin"

    
* In doc.ps1 wird dot.exe automatisch gesucht; alternativ Pfad hart setzen.
    

**„unsupported cell type '$add'“ in nextpnr**

* Es fehlt die Tech-Mappung. Nutze **synth_ice40** vor nextpnr (in build.ps1/doc.ps1 bereits enthalten).
    

**unmatched constraint 'RX'/'TX'**

* In io.pcf ist ein Port genannt, den es im Top-Modul nicht gibt. Temporär auskommentieren oder Port im RTL anlegen.
    

**PowerShell-Parserfehler mit Umlauten/€/**✓**/**…**

* Skripte als **UTF-8 (ohne BOM)** speichern.
    
* In Strings **ASCII** verwenden; deutsche Texte in Kommentaren statt in String-Literals.
    

**GTKWAVE öffnet sich nicht**

* sim.ps1 ohne -OpenWave gestartet oder gtkwave fehlt im PATH. Teste:
    
    
powershell
    gtkwave .\build\tb_top.vcd

    

* * *

## Tipps für saubere Repos

* build/ und docs/ sind **generiert** → in .gitignore aufnehmen (oder CI-Artefakte bewusst einchecken, wenn gewünscht).
    
* Einheitliche **Datei-Endungen** (.v für RTL, .vhd bei VHDL, .pcf für Pins).
    
* **Kleine, fokussierte Testbenches** pro Modul – schneller durchs Feedback-Karussell.
    
* Skripte: **Parametrisieren** statt zu kopieren (Top/PCF/Seed/Freq).
    
* **README aktualisieren**, wenn neue Skripte/Ordner dazu kommen.
    

* * *

## Weiterdenken

* **CI (GitHub Actions)**: Windows-Runner + OSS CAD Suite installieren, anschließend sim.ps1, doc.ps1 (SVG/Reports als Artefakte).
    
* **Warmboot/Multiboot**: mehrere Bitstreams bündeln (icemulti) und per SB_WARMBOOT wechseln.
    
* **Formale Checks**: SymbiYosys für kleine Steuerlogiken, bevor sie wachsen.
    
* **HFOSC/PLL**: Für eigenständige Takterzeugung SB_HFOSC nutzen; bei größeren iCE40-Varianten PLL-Parameter via icepll.
    

* * *

## Lizenzhinweis

* **OSS CAD Suite** & Tools (Yosys, nextpnr, Icestorm etc.) haben **eigene Lizenzen**.
    
* Die **Template-Skripte/Struktur** in diesem Repo kannst du mit einer passenden freien Lizenz versehen (z. B. MIT).
    
* Datenblätter/Pinouts der Boards unterliegen den jeweiligen Herstellern.
    

* * *

### Quickstart (zwei Befehle)


powershell
. C:\oss-cad-suite\environment.ps1
.\scripts\build.ps1


Das bringt dich von **RTL** zu **bitstream** und lädt ihn in den **SRAM** deines IceSugarNano. Danach: .\scripts\sim.ps1 -OpenWave für die Wellenform und .\scripts\doc.ps1 für die Doku-SVGs & Timing. Future-you wird dir danken.