# Spindle-Pole-Behind-Between-Ratio

**Repository:** https://github.com/kskendo/Spindle-Pole-Behind-Between-Ratio

Fiji/ImageJ macro that measures, in two channels, the mean intensity **behind each spindle pole** and **between the poles**, and the ratio behind / between. Used to quantify the redistribution of α-tubulin, PRC1 and HAUS6 after low-dose taxol.

Developed for:
> Skendo K, Harry D, Castrogiovanni C, Meraldi P. Spindle assembly factors form and stabilize bridging microtubules. *Cell Reports* (in revision).

---

## What it measures

```
   behind 1            between              behind 2
 [  L µm  ] P1 [   pole 1 -> pole 2   ] P2 [  L µm  ]      all boxes W µm wide
```

For each cell:
1. You click pole 1 and pole 2 (multi-point tool).
2. You draw a background box in the cytoplasm, away from the spindle.
3. The macro places three rotated rectangles along the spindle axis: one from pole to pole, and one behind each pole, pointing away from the other pole.
4. In each rectangle and channel it measures the mean intensity and subtracts the background mean.
5. The two behind-pole values are averaged, and the ratio behind / between is calculated per channel.

Defaults: box width **W = 3 µm**, behind-pole length **L = 2 µm**.

---

## Requirements

- [Fiji/ImageJ](https://fiji.sc) (uses script parameters `#@`, so run it from the script editor or Plugins > Macros > Run)
- Multi-channel sum projections (`.tif`/`.tiff`) with the pixel size set in µm (or a fallback pixel size given in the dialog)

---

## Usage

1. Organize the images in folders, e.g. `main/15nM_REP1/<image>_SUM.tif`. Condition and replicate are read from the folder or file name (set in the dialog; default = parent folder split at `_`: part 1 = condition, part 2 = replicate).
2. Run the macro and fill in the dialog: main folder, file-name filter (default `SUM`), the two channel numbers and names, box width and behind-pole length.
3. For every image: click the two poles → OK, draw the background box → OK. Several cells per image are possible; click OK without points to go to the next image. Esc stops the run.
4. Results are saved after every cell. Re-running skips images already measured, so you can stop and continue later.
5. Tick "Only rebuild the summary from existing results" to regenerate the summary files without measuring.

---

## Output (in the main folder)

| File | Content |
|------|---------|
| `<name>.csv` | One row per cell: condition, replicate, spindle length (µm, from the pole positions), between / behind pole 1 / behind pole 2 / behind mean intensities and ratio for both channels, background values, pole coordinates, box sizes |
| `<name>_per_replicate.csv` | Mean and SD per condition and replicate |
| `<name>_per_condition.csv` | Mean ± SD of replicate means, and of all cells |
| `<name>_prism_<channel>.csv` | Ratio replicate means, rows = replicates, columns = conditions (Prism-ready) |
| `QC_<name>/` | PNG of every measured cell with the boxes drawn (between = yellow, behind = magenta, background = cyan) |

---

## Citation

> Skendo K et al. Spindle assembly factors form and stabilize bridging microtubules. *Cell Reports*. DOI to be added upon publication.

## License

MIT License — see `LICENSE`.

## Contact

Kristjana Skendo, Meraldi Lab, Department of Cell Physiology and Metabolism, University of Geneva
Lead contact: patrick.meraldi@unige.ch
