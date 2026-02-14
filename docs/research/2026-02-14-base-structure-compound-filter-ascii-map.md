# Base_Structure_Compound_Filter · Clean Pattern Sketches

Left side is oldest structure context and right side is present.
`E` marks the entry point (`S1` current extremum).
Each sketch stops at `E` (no post-entry projection).

Source of truth:
- `services/core/enums.mqh` (`TrendStructureCompoundModes`)
- `services/trading_signals/structure_compound_modes.mqh` (canonical templates)

## Legend

- `o`: historical pivot
- `E`: entry pivot (current `S1`)

## Mode Map

| Value | Mode | Template `[S1,S2,S3,S4]` |
|---:|---|---|
| `0` | `COMPOUND_MODE_OFF` | Force-pass structure filter (no template match required) |
| `1` | `COMPOUND_MODE_TREND_RIDE_BUY` | `[HL, HH, HL, HH]` |
| `2` | `COMPOUND_MODE_TREND_RIDE_SELL` | `[LL, LH, LL, LH]` |
| `3` | `COMPOUND_MODE_PULLBACK_CONTINUE_BUY` | `[HL, HH, LL, LH]` |
| `4` | `COMPOUND_MODE_PULLBACK_CONTINUE_SELL` | `[LL, LH, HL, HH]` |
| `5` | `COMPOUND_MODE_REVERSAL_EARLY_BUY` | `[HL, LH, LL, LH]` |
| `6` | `COMPOUND_MODE_REVERSAL_EARLY_SELL` | `[LH, HL, HH, HL]` |
| `7` | `COMPOUND_MODE_BREAKOUT_READY_BUY` | `[HL, HH, EQ, EQ]` |
| `8` | `COMPOUND_MODE_BREAKOUT_READY_SELL` | `[LL, LH, EQ, EQ]` |
| `9` | `COMPOUND_MODE_BREAKOUT_FOLLOW_BUY` | `[EQ, EQ, HL, HH]` |
| `10` | `COMPOUND_MODE_BREAKOUT_FOLLOW_SELL` | `[EQ, EQ, LH, LL]` |
| `11` | `COMPOUND_MODE_CHOP_GUARD` | `[HL, LH, HL, LH]` |
| `12` | `COMPOUND_MODE_VOLATILITY_TRAP` | `[LL, HH, LL, HH]` |
| `13` | `COMPOUND_MODE_COMPRESSION_WAIT` | `[EQ, EQ, EQ, EQ]` |

## Pattern Sketches

### `0` `COMPOUND_MODE_OFF`

```text
Structure template matching is disabled (force-pass).
```

### `1` `COMPOUND_MODE_TREND_RIDE_BUY` `[HL, HH, HL, HH]`

```text
               o\
     o\      //  \\
   //  \\  //      \E
 //      \o
o
```

### `2` `COMPOUND_MODE_TREND_RIDE_SELL` `[LL, LH, LL, LH]`

```text
     o
   // \        o
 //    \\    // \
o        \ //    \\
          o        \
                    E
```

### `3` `COMPOUND_MODE_PULLBACK_CONTINUE_BUY` `[HL, HH, LL, LH]`

```text
     o
   // \        o\
 //    \\    //  \\
o        \ //      \E
          o
```

### `4` `COMPOUND_MODE_PULLBACK_CONTINUE_SELL` `[LL, LH, HL, HH]`

```text
               o
     o\      // \
   //  \\  //    \\
 //      \o        \
o                   E
```

### `5` `COMPOUND_MODE_REVERSAL_EARLY_BUY` `[HL, LH, LL, LH]`

```text
     o
    / \        o
   /   \      / \
  /          /   \\
 /      \   /      \
o        \ /        E
          o
```

### `6` `COMPOUND_MODE_REVERSAL_EARLY_SELL` `[LH, HL, HH, HL]`

```text
             //o\
   //o----o//    \\
o//                \E
```

### `7` `COMPOUND_MODE_BREAKOUT_READY_BUY` `[HL, HH, EQ, EQ]`

```text
     o         o\
   // \\     //  \\
 //     \\ //      \E
o         o
```

### `8` `COMPOUND_MODE_BREAKOUT_READY_SELL` `[LL, LH, EQ, EQ]`

```text
     o         o
   // \\     // \
 //     \\ //    \\
o         o        \
                    E
```

### `9` `COMPOUND_MODE_BREAKOUT_FOLLOW_BUY` `[EQ, EQ, HL, HH]`

```text
               o
     o\      // \\
   //  \\  //     \\
 //      \o         E
o
```

### `10` `COMPOUND_MODE_BREAKOUT_FOLLOW_SELL` `[EQ, EQ, LH, LL]`

```text
     o
   // \        o
 //    \\    // \\
o        \ //     \\
          o         E
```

### `11` `COMPOUND_MODE_CHOP_GUARD` `[HL, LH, HL, LH]`

```text
     o
    / \        o
       \      / \
   /         /   \\
  /     \   /      \
         \ /        E
 /        o
o
```

### `12` `COMPOUND_MODE_VOLATILITY_TRAP` `[LL, HH, LL, HH]`

```text
o\\          //o\
   \\o----o//    \\
                   \E
```

### `13` `COMPOUND_MODE_COMPRESSION_WAIT` `[EQ, EQ, EQ, EQ]`

```text
     o         o
   // \\     // \\
 //     \\ //     \\
o         o         E
```
