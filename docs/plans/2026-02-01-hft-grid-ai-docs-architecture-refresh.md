# HFT Grid AI Docs + Services Consolidation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Merge `microservices/` into a single ordered `services/` tree, keep the include pipeline sequential, create a new MQL5 Quant/Math skill, and refresh README/AGENTS to be brief and accurate (with a short pointer to the Codex config).

**Architecture:** Keep the top-level include chain in `HFT_Grid_AI.mq5` unchanged and sequential. Move all microservices code into `services/{core,utils,indicators,trading_signals,frontend}` and update aggregators to reference the new paths. Create a dedicated MQL5 Quant/Math skill (expert MQL5 dev + quant + math, Context7-first) and reference it from AGENTS. Documentation is minimal: README covers purpose + quick start + version/contact metadata; AGENTS stays brief and points to the new skill and `~/.codex/config.toml`.

**Tech Stack:** MQL5 (MetaTrader 5), MetaEditor/Strategy Tester, Git.

---

## Pre-flight (required before tasks)

- Create a dedicated worktree if you are not already in one.
  - Run: `git rev-parse --show-toplevel`
  - Run: `git worktree add ../HFT_Grid_AI-arch-refresh`
- Snapshot current microservices files for verification later:
  - Run: `find microservices -type f`

---

### Task 1: Create the MQL5 Functional Skill (do this first)

**Files:**
- Create: `/home/loldlm/.agents/skills/mql5-functional/SKILL.md`
- Create: `/home/loldlm/.codex/skills/mql5-functional` (symlink to the skill folder)

**Step 1: Write the failing test**

Test command (should fail before the skill exists):
```bash
test -f /home/loldlm/.agents/skills/mql5-functional/SKILL.md
```

**Step 2: Run test to verify it fails**

Run: `test -f /home/loldlm/.agents/skills/mql5-functional/SKILL.md`
Expected: FAIL (file does not exist).

**Step 3: Write minimal implementation**

Create the skill file at `/home/loldlm/.agents/skills/mql5-functional/SKILL.md` with:
```markdown
---
name: mql5-functional
description: Expert MQL5 + Quant/Math guidance for HFT Grid AI EA functional architecture, code standards, math, and risk logic.
---

# MQL5 Functional Skill (HFT Grid AI)

## Role
You are an expert MQL5 developer, quant trader, and math expert.

## Scope
- Code standards and struct conventions for this EA.
- Functional, sequential include pipeline rules.
- Grid math: spacing (ATR/points/channel midline), lot sizing modes, trailing and break-even logic.
- Structure filters and risk controls.

## Architecture Constraints
- Top-level include chain is sequential and fixed: tools -> management -> strategies -> signals -> frontend.
- Services may only include lower layers (or core/utils/indicators); no sibling includes.
- Prefer explicit constructors with initializer lists; add copy constructors when structs are passed/assigned.
- If a struct has a constructor, do not use aggregate initialization; add a default constructor when arrays are required.

## Code Standards
- Follow the naming/style conventions in `AGENTS.md`.
- Avoid C++11 features (no `auto`, lambdas, range-for).

## Documentation + Research
- Use Context7 MCP for MQL5 documentation and syntax confirmation.
  - Resolve the library ID first, then query docs.
  - Prefer official MQL5 docs when clarifying language or platform behavior.

## Output Style
- Concise, test-ready, and aligned to the include pipeline and services ownership.
```

**Step 4: Run test to verify it passes**

Run: `test -f /home/loldlm/.agents/skills/mql5-functional/SKILL.md`
Expected: PASS.

**Step 5: Create Codex symlink**

```bash
mkdir -p /home/loldlm/.codex/skills
ln -sfn /home/loldlm/.agents/skills/mql5-functional /home/loldlm/.codex/skills/mql5-functional
```

**Step 6: Verify symlink**

Run: `test -L /home/loldlm/.codex/skills/mql5-functional`
Expected: PASS.

**Note:** From Task 2 onward, follow the guidance in the new skill.

---

### Task 2: Merge `microservices/core` + `microservices/utils` into `services/`

**Files:**
- Create: `services/core/`
- Create: `services/utils/`
- Move: `microservices/core/*.mqh` -> `services/core/*.mqh`
- Move: `microservices/utils/*.mqh` -> `services/utils/*.mqh`
- Modify: `services/trading_tools.mqh`

**Step 1: Write the failing test**

Test command (should return no matches once fixed):
```bash
rg "microservices/(core|utils)" services/trading_tools.mqh
```

**Step 2: Run test to verify it fails**

Run: `rg "microservices/(core|utils)" services/trading_tools.mqh`
Expected: FAIL (matches found).

**Step 3: Write minimal implementation**

Run:
```bash
mkdir -p services/core services/utils
git mv microservices/core/*.mqh services/core/
git mv microservices/utils/*.mqh services/utils/
```

Update the include block in `services/trading_tools.mqh` to:
```mql5
// CORE SERVICES
#include "core/enums.mqh"
#include "core/base_structures.mqh"

// UTILITY SERVICES
#include "utils/array_functions.mqh"
#include "utils/miscellaneous.mqh"
#include "utils/money_functions.mqh"
#include "utils/logs_helper.mqh"
#include "utils/broker_constraints_helper.mqh"
#include "utils/price_math.mqh"
#include "utils/file_logger.mqh"
```

**Step 4: Run test to verify it passes**

Run: `rg "microservices/(core|utils)" services/trading_tools.mqh`
Expected: PASS (no matches).

**Step 5: Commit**

```bash
git add services/trading_tools.mqh services/core services/utils
git commit -m "refactor: move core/utils into services"
```

---

### Task 3: Merge `microservices/indicators` into `services/indicators`

**Files:**
- Create: `services/indicators/`
- Move: `microservices/indicators/*.mqh` -> `services/indicators/*.mqh`
- Modify: `services/trading_signals.mqh`

**Step 1: Write the failing test**

Test command (should return no matches once fixed):
```bash
rg "microservices/indicators" services/trading_signals.mqh
```

**Step 2: Run test to verify it fails**

Run: `rg "microservices/indicators" services/trading_signals.mqh`
Expected: FAIL (matches found).

**Step 3: Write minimal implementation**

Run:
```bash
mkdir -p services/indicators
git mv microservices/indicators/*.mqh services/indicators/
```

Update the indicator include section in `services/trading_signals.mqh` to:
```mql5
// INDICATOR SERVICES
#include "indicators/bands_percent_indicator.mqh"
#include "indicators/alligator_indicator.mqh"
#include "indicators/stochastic_indicator.mqh"
#include "indicators/stochastic_market_indicator.mqh"
#include "indicators/body_ma_indicator.mqh"
```

**Step 4: Run test to verify it passes**

Run: `rg "microservices/indicators" services/trading_signals.mqh`
Expected: PASS (no matches).

**Step 5: Commit**

```bash
git add services/trading_signals.mqh services/indicators
git commit -m "refactor: move indicators into services"
```

---

### Task 4: Merge `microservices/trading_signals` into `services/trading_signals`

**Files:**
- Move: `microservices/trading_signals/*.mqh` -> `services/trading_signals/*.mqh`
- Modify: `services/trading_signals.mqh`

**Step 1: Write the failing test**

Test command (should return no matches once fixed):
```bash
rg "microservices/trading_signals" services/trading_signals.mqh
```

**Step 2: Run test to verify it fails**

Run: `rg "microservices/trading_signals" services/trading_signals.mqh`
Expected: FAIL (matches found).

**Step 3: Write minimal implementation**

Run:
```bash
git mv microservices/trading_signals/*.mqh services/trading_signals/
```

Replace the include block in `services/trading_signals.mqh` with this ordered list:
```mql5
// INDICATOR SERVICES
#include "indicators/bands_percent_indicator.mqh"
#include "indicators/alligator_indicator.mqh"
#include "indicators/stochastic_indicator.mqh"
#include "indicators/stochastic_market_indicator.mqh"
#include "indicators/body_ma_indicator.mqh"

// SIGNAL SERVICE FILES
#include "trading_signals/grid_channel_utils.mqh"
#include "trading_signals/signal_params_struct.mqh"
#include "trading_signals/session_time_filter_manager.mqh"
#include "trading_signals/market_signal_state.mqh"
#include "trading_signals/market_signal_indicators.mqh"
#include "trading_signals/market_signal_channel_guards.mqh"
#include "trading_signals/market_signal_filters.mqh"
#include "trading_signals/market_signal_cleanup.mqh"
#include "trading_signals/market_signal_detection.mqh"
#include "trading_signals/market_status_controller.mqh"
#include "trading_signals/grid_price_resolver.mqh"
#include "trading_signals/grid_order_helpers.mqh"
#include "trading_signals/grid_break_even_utils.mqh"
#include "trading_signals/grid_order_math.mqh"
#include "trading_signals/grid_order_logging.mqh"
#include "trading_signals/grid_order_lifecycle.mqh"
#include "trading_signals/grid_planner.mqh"
#include "trading_management_strategies/grid_risk_trend_strategy.mqh"
#include "trading_management_strategies/grid_trend_risk_hedge.mqh"
#include "trading_management_strategies/grid_trend_risk_breach.mqh"
#include "trading_management_strategies/grid_trend_risk_sar.mqh"
#include "trading_management_strategies/grid_trend_risk_modes.mqh"
#include "trading_signals/grid_trend_risk_manager.mqh"
#include "trading_signals/grid_order_controller.mqh"
#include "trading_signals/tick_signals_manager.mqh"
#include "trading_signals/protection_risk_filter.mqh"
```

**Step 4: Run test to verify it passes**

Run: `rg "microservices/trading_signals" services/trading_signals.mqh`
Expected: PASS (no matches).

**Step 5: Commit**

```bash
git add services/trading_signals.mqh services/trading_signals
git commit -m "refactor: move trading_signals helpers into services"
```

---

### Task 5: Merge `microservices/frontend` into `services/frontend`

**Files:**
- Move: `microservices/frontend/*.mqh` -> `services/frontend/*.mqh`
- Modify: `services/frontend.mqh`

**Step 1: Write the failing test**

Test command (should return no matches once fixed):
```bash
rg "microservices/frontend" services/frontend.mqh
```

**Step 2: Run test to verify it fails**

Run: `rg "microservices/frontend" services/frontend.mqh`
Expected: FAIL (matches found).

**Step 3: Write minimal implementation**

Run:
```bash
git mv microservices/frontend/*.mqh services/frontend/
```

Update the include block in `services/frontend.mqh` to:
```mql5
// FRONTEND SERVICE FILES
#include "frontend/ea_license_light_version.mqh"
#include "frontend/chart_style_guide.mqh"
#include "frontend/grid_visual_utils.mqh"
#include "frontend/grid_visual_lines.mqh"
#include "frontend/grid_visualization.mqh"
```

**Step 4: Run test to verify it passes**

Run: `rg "microservices/frontend" services/frontend.mqh`
Expected: PASS (no matches).

**Step 5: Commit**

```bash
git add services/frontend.mqh services/frontend
git commit -m "refactor: move frontend helpers into services"
```

---

### Task 6: Refresh `README.md` to be brief + purpose-only (keep version/contact)

**Files:**
- Modify: `README.md`

**Step 1: Write the failing test**

Test command (should return no matches once README is short):
```bash
rg "Architecture Map|Signal Engine Essentials|Input Reference|Developer Notes" README.md
```

**Step 2: Run test to verify it fails**

Run: `rg "Architecture Map|Signal Engine Essentials|Input Reference|Developer Notes" README.md`
Expected: FAIL (matches found).

**Step 3: Write minimal implementation**

Replace `README.md` with:
```markdown
# HFT Grid AI EA

**Version:** 1.10
**Platform:** MetaTrader 5 (MQL5)
**Contact:** @loldlm · https://t.me/TradingAlgoritmicoFx

HFT Grid AI is a MetaTrader 5 Expert Advisor that runs bullish/bearish grid sequences gated by multi-timeframe context filters and strict risk controls.

**Entrypoint:** `HFT_Grid_AI.mq5`

## Quick Start
1. Open `HFT_Grid_AI.mq5` in MetaEditor and compile.
2. Attach the EA to a chart or run it in Strategy Tester (Every tick based on real ticks).
3. Adjust inputs in MT5 as needed.

## Project Map (brief)
- `services/` holds the ordered include pipeline (tools -> management -> strategies -> signals -> frontend).
- `AGENTS.md` is the short architectural brief and source of truth for contributor rules.
```

**Step 4: Run test to verify it passes**

Run: `rg "Architecture Map|Signal Engine Essentials|Input Reference|Developer Notes" README.md`
Expected: PASS (no matches).

**Step 5: Commit**

```bash
git add README.md
git commit -m "docs: shorten README to purpose and quick start"
```

---

### Task 7: Refresh `AGENTS.md` to the new brief + point to Codex config + new skill

**Files:**
- Modify: `AGENTS.md`

**Step 1: Write the failing test**

Test command (should match once the new brief is in place):
```bash
rg "Functional Include Pipeline|Skill|Codex Config|ALL_CAPS|CamelCase|snake_case" AGENTS.md
```

**Step 2: Run test to verify it fails**

Run: `rg "Functional Include Pipeline|Skill|Codex Config|ALL_CAPS|CamelCase|snake_case" AGENTS.md`
Expected: FAIL (no matches).

**Step 3: Write minimal implementation**

Replace `AGENTS.md` with:
```markdown
# AGENTS Brief · HFT Grid AI EA

Short, current notes for contributors. Keep this file brief; deep details live in code.

---

## 1) Purpose + Entrypoint
- **Purpose**: MT5 grid EA that runs bullish/bearish sequences gated by multi-timeframe context filters and strict risk controls.
- **Entrypoint**: `HFT_Grid_AI.mq5`.

## 2) Functional Include Pipeline (single ordered chain)
The EA follows a functional, sequential include chain. Keep this order and avoid sibling includes.

```
services/Bcrypt.mqh
services/SecurityLicense.mqh
services/trading_tools.mqh
services/trading_management.mqh
services/trading_management_strategies.mqh
services/trading_signals.mqh
services/frontend.mqh
```

Rules:
- Only include lower layers (or core/utils/indicators); never include siblings.
- Aggregators are the single source of truth for include order.

## 3) One Source of Truth: merge `microservices/` into `services/`
Goal: one ordered services tree with clear ownership and include order.

Proposed mapping:
- `microservices/core/*` -> `services/core/*`
- `microservices/utils/*` -> `services/utils/*`
- `microservices/indicators/*` -> `services/indicators/*`
- `microservices/trading_signals/*` -> `services/trading_signals/*` (merge into existing)
- `microservices/frontend/*` -> `services/frontend/*` (merge into existing)

Minimal migration steps:
1. Move files into the mapped `services/*` folders (keep filenames).
2. Update `services/*.mqh` aggregators and any direct includes to the new paths.
3. Remove `microservices/` after the move (no shims).

## 4) Struct & Style Conventions
- Prefer explicit constructors with initializer lists; add a copy constructor when structs are passed/assigned.
- If a struct has a constructor, do not use aggregate initialization; add a default constructor when arrays are required.
- Style: 2-space indentation, snake_case variables, CamelCase functions, ALL_CAPS enums/constants. Avoid C++11 features (`auto`, lambdas, range-for).
- Keep the code functional and sequential: inputs -> indicators -> filters -> signal detection -> grid plan -> order lifecycle -> protection -> frontend.

## 5) Skill (Quant/Math + MQL5)
- **Skill path**: `/home/loldlm/.agents/skills/mql5-functional/SKILL.md`
- Scope: grid spacing math (ATR/points/channel midline), lot sizing modes, trailing/break-even logic, structure filters, and risk controls.
- Output style: concise, test-ready, and aligned to the include pipeline above.
- Uses Context7 MCP for MQL5 documentation.

## 6) Codex Config (source of truth)
Keep this in sync with `~/.codex/config.toml` (do not copy here).

**Step 4: Run test to verify it passes**

Run: `rg "Functional Include Pipeline|Skill|Codex Config|ALL_CAPS|CamelCase|snake_case" AGENTS.md`
Expected: PASS (matches found).

**Step 5: Commit**

```bash
git add AGENTS.md
git commit -m "docs: refresh AGENTS brief and codex setup"
```

---

### Task 8: Remove empty `microservices/` directory (no shims)

**Files:**
- Delete: `microservices/` (empty)

**Step 1: Write the failing test**

Test command (directory should be gone once cleaned):
```bash
test ! -d microservices
```

**Step 2: Run test to verify it fails**

Run: `test ! -d microservices`
Expected: FAIL (directory still exists).

**Step 3: Write minimal implementation**

If the directory is empty:
```bash
find microservices -type d -empty -delete
```

**Step 4: Run test to verify it passes**

Run: `test ! -d microservices`
Expected: PASS (directory removed).

**Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove empty microservices directory"
```

---

## Verification (after all tasks)

- Ensure no legacy include paths remain:
  - Run: `rg "#include .*microservices/" -n`
  - Expected: no matches.
- Compile `HFT_Grid_AI.mq5` in MetaEditor.
  - Expected: no missing include errors.
