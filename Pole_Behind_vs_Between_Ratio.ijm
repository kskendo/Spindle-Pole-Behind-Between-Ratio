// Pole_Behind_vs_Between_Ratio.ijm
//
// Measures, in two channels, the mean intensity BEHIND each spindle pole versus
// BETWEEN the poles, and the ratio behind / between.
//
// For every SUM projection found in the main folder and its subfolders:
//   1. you click pole 1 and pole 2 (multi-point tool)
//   2. you draw a background box in the cytoplasm
//   The macro then places three boxes along the spindle axis:
//
//        behind 1          between            behind 2
//      [  L um  ] P1 [ pole 1 -> pole 2 ] P2 [  L um  ]      (all W um wide)
//
//   and measures each channel (background subtracted).
//   Several cells per image are possible. Results are saved after every cell,
//   so you can stop at any time (Esc) and re-run later: images already
//   measured are skipped.
//
// Output (in the main folder):
//   <name>.csv                    one row per cell
//   <name>_per_replicate.csv      mean per condition x replicate
//   <name>_per_condition.csv      mean +/- SD of replicate means, and of all cells
//   <name>_prism_<channel>.csv    ratio, replicate means: rows = replicates, columns = conditions
//   QC_<name>/                    PNG of every measured cell with the boxes drawn
//
// Condition and replicate are read from the folder structure or the file name
// (see dialog). Default: the image's folder name split at "_", part 1 = condition,
// part 2 = replicate, e.g. .../15nM_REP1/<image>_SUM.tif -> condition 15nM, replicate REP1

#@ File (label = "Main folder (subfolders are searched too)", style = "directory") mainDir
#@ String (label = "Use files whose name contains", value = "SUM") nameFilter
#@ Integer (label = "Channel A number", value = 1) chA
#@ String (label = "Channel A name", value = "tubulin") nameA
#@ Integer (label = "Channel B number", value = 2) chB
#@ String (label = "Channel B name", value = "HAUS6") nameB
#@ Float (label = "Box width (um)", value = 3.0) boxWidthUm
#@ Float (label = "Behind-pole box length (um)", value = 2.0) behindLengthUm
#@ Float (label = "Pixel size if image is uncalibrated (um, 0 = stop)", value = 0) fallbackPx
#@ String (label = "Condition comes from", choices = {"parent folder part", "parent folder", "grandparent folder", "grandparent folder part", "file name part"}) condSource
#@ Integer (label = "   part number for condition (name split at _ , 1 = first)", value = 1) condPart
#@ String (label = "Replicate comes from", choices = {"parent folder part", "parent folder", "grandparent folder", "grandparent folder part", "file name part"}) repSource
#@ Integer (label = "   part number for replicate", value = 2) repPart
#@ String (label = "Results file name", value = "pole_ratios") outName
#@ Boolean (label = "Only rebuild the summary from existing results", value = false) summaryOnly

var fileList = newArray(0);
var gFilter = "";
var gTbl = "";
var gRoot = "";
var gOut = "";
var gNameA = "";
var gNameB = "";
var gRatioA = "";
var gRatioB = "";

rootDir = mainDir + File.separator;
csvPath = rootDir + outName + ".csv";
tbl = outName + ".csv";
qcDir = rootDir + "QC_" + outName + File.separator;
ratioA = nameA + "_ratio_behind_between";
ratioB = nameB + "_ratio_behind_between";
gFilter = nameFilter; gRoot = rootDir; gOut = outName;
gNameA = nameA; gNameB = nameB; gRatioA = ratioA; gRatioB = ratioB;

// ---- results table: open existing one (resume) or start a new one ----------
if (isOpen(tbl)) { selectWindow(tbl); run("Close"); }
if (File.exists(csvPath)) {
    Table.open(csvPath);
    tbl = Table.title;
} else {
    Table.create(tbl);
}
gTbl = tbl;
done = "|";
for (r = 0; r < Table.size(tbl); r++)
    done = done + Table.getString("file", r, tbl) + "|";

if (summaryOnly) {
    summarize();
    exit("Summary rebuilt from " + Table.size(tbl) + " cells.");
}

// ---- find files ------------------------------------------------------------
listFiles(rootDir);
if (fileList.length == 0)
    exit("No .tif files containing '" + nameFilter + "' found in\n" + rootDir);
File.makeDirectory(qcDir);
print("\\Clear");
print("Found " + fileList.length + " file(s). Already measured cells: " + Table.size(tbl));

setBatchMode(false);
maxCh = maxOf(chA, chB);

for (f = 0; f < fileList.length; f++) {
    path = fileList[f];
    rel = substring(path, lengthOf(rootDir));
    rel = replace(rel, "\\\\", "/");
    if (indexOf(done, "|" + rel + "|") >= 0) continue;

    cond = getLabel(path, condSource, condPart);
    rep = getLabel(path, repSource, repPart);

    open(path);
    id = getImageID();
    title = getTitle();
    getDimensions(w, h, nc, nz, nt);
    if (nc < maxCh) {
        print("SKIPPED (only " + nc + " channel(s)): " + rel);
        close();
        continue;
    }
    getPixelSize(unit, pw, ph);
    if (unit == "pixel" || unit == "pixels" || unit == "") {
        if (fallbackPx <= 0)
            exit("Image has no pixel size:\n" + rel + "\nRe-run and set 'Pixel size if image is uncalibrated'.");
        pw = fallbackPx;
    }
    if (nc > 1) Stack.setDisplayMode("composite");
    for (c = 1; c <= nc; c++) {
        if (nc > 1) Stack.setChannel(c);
        run("Enhance Contrast", "saturated=0.35");
    }
    Overlay.remove;

    cellN = 0;
    more = true;
    while (more) {
        // -- poles
        run("Select None");
        setTool("multipoint");
        waitForUser("Cell " + (cellN + 1) + "  |  " + cond + "  |  " + rep + "  |  file " + (f + 1) + "/" + fileList.length,
            "Click POLE 1, then POLE 2 (multi-point tool), then OK.\n \n" +
            "No points + OK  =  done with this image / skip it.\n" +
            "Esc  =  stop (everything measured so far is saved).");
        if (selectionType() != 10) { more = false; break; }
        getSelectionCoordinates(xs, ys);
        if (xs.length < 2) { more = false; break; }
        x1 = xs[0]; y1 = ys[0]; x2 = xs[1]; y2 = ys[1];
        dx = x2 - x1; dy = y2 - y1;
        lenPx = sqrt(dx * dx + dy * dy);
        if (lenPx < 2) { showMessage("The two poles are on the same spot - try again."); continue; }
        ux = dx / lenPx; uy = dy / lenPx;
        wPx = boxWidthUm / pw;
        lPx = behindLengthUm / pw;

        // -- background
        run("Select None");
        setTool("rectangle");
        bgOk = false;
        while (!bgOk) {
            waitForUser("Background", "Draw a box in the cytoplasm, away from the spindle, then OK.");
            t = selectionType();
            if (t >= 0 && t <= 4) bgOk = true;
        }
        getSelectionBounds(bx, by, bw, bh);
        bgA = meanIn(chA);
        bgB = meanIn(chB);

        // -- between: pole 1 -> pole 2
        makeRotatedRectangle(x1, y1, x2, y2, wPx);
        betA = meanIn(chA) - bgA;
        betB = meanIn(chB) - bgB;
        Overlay.addSelection("yellow");

        // -- behind pole 1 (pointing away from pole 2)
        makeRotatedRectangle(x1, y1, x1 - ux * lPx, y1 - uy * lPx, wPx);
        b1A = meanIn(chA) - bgA;
        b1B = meanIn(chB) - bgB;
        Overlay.addSelection("magenta");

        // -- behind pole 2 (pointing away from pole 1)
        makeRotatedRectangle(x2, y2, x2 + ux * lPx, y2 + uy * lPx, wPx);
        b2A = meanIn(chA) - bgA;
        b2B = meanIn(chB) - bgB;
        Overlay.addSelection("magenta");

        makeRectangle(bx, by, bw, bh);
        Overlay.addSelection("cyan");
        makePoint(x1, y1);
        Overlay.addSelection("white");
        makePoint(x2, y2);
        Overlay.addSelection("white");
        run("Select None");

        behA = (b1A + b2A) / 2;
        behB = (b1B + b2B) / 2;
        cellN++;

        // -- write row and save immediately
        row = Table.size(tbl);
        Table.set("file", row, rel, tbl);
        Table.set("condition", row, cond, tbl);
        Table.set("replicate", row, rep, tbl);
        Table.set("cell", row, cellN, tbl);
        Table.set("spindle_length_um", row, lenPx * pw, tbl);
        Table.set(nameA + "_between", row, betA, tbl);
        Table.set(nameA + "_behind_pole1", row, b1A, tbl);
        Table.set(nameA + "_behind_pole2", row, b2A, tbl);
        Table.set(nameA + "_behind_mean", row, behA, tbl);
        Table.set(ratioA, row, behA / betA, tbl);
        Table.set(nameB + "_between", row, betB, tbl);
        Table.set(nameB + "_behind_pole1", row, b1B, tbl);
        Table.set(nameB + "_behind_pole2", row, b2B, tbl);
        Table.set(nameB + "_behind_mean", row, behB, tbl);
        Table.set(ratioB, row, behB / betB, tbl);
        Table.set(nameA + "_background", row, bgA, tbl);
        Table.set(nameB + "_background", row, bgB, tbl);
        Table.set("pole1_x", row, x1, tbl);
        Table.set("pole1_y", row, y1, tbl);
        Table.set("pole2_x", row, x2, tbl);
        Table.set("pole2_y", row, y2, tbl);
        Table.set("box_width_um", row, boxWidthUm, tbl);
        Table.set("behind_length_um", row, behindLengthUm, tbl);
        Table.update(tbl);
        Table.save(csvPath, tbl);

        // -- QC image with all boxes
        setBatchMode(true);
        selectImage(id);
        run("Flatten");
        flatId = getImageID();
        if (flatId != id) {
            saveAs("PNG", qcDir + File.getNameWithoutExtension(path) + "_cell" + cellN + ".png");
            selectImage(flatId);
            close();
        }
        setBatchMode(false);
        selectImage(id);

        print(rel + "  cell " + cellN + ":  " + nameA + " ratio " + d2s(behA / betA, 3) +
              ",  " + nameB + " ratio " + d2s(behB / betB, 3));
    }
    selectImage(id);
    close();
}

summarize();
showMessage("Done", "Measured cells in total: " + Table.size(tbl) + "\n \nResults and summaries saved in:\n" + rootDir);


// ============================================================================
function meanIn(ch) {
    Stack.setChannel(ch);
    getStatistics(area, mean);
    return mean;
}

function listFiles(dir) {
    list = getFileList(dir);
    for (i = 0; i < list.length; i++) {
        if (endsWith(list[i], "/")) {
            if (!startsWith(list[i], "QC_")) listFiles(dir + list[i]);
        } else {
            lower = toLowerCase(list[i]);
            if (indexOf(list[i], gFilter) >= 0 && (endsWith(lower, ".tif") || endsWith(lower, ".tiff")))
                fileList = Array.concat(fileList, dir + list[i]);
        }
    }
}

function getLabel(path, source, part) {
    parent = File.getParent(path);
    if (source == "parent folder") return File.getName(parent);
    if (source == "grandparent folder") return File.getName(File.getParent(parent));
    if (source == "parent folder part") name = File.getName(parent);
    else if (source == "grandparent folder part") name = File.getName(File.getParent(parent));
    else name = File.getNameWithoutExtension(path);
    parts = split(name, "_");
    if (part >= 1 && part <= parts.length) return parts[part - 1];
    return "unknown";
}

function unique(a) {
    b = Array.copy(a);
    Array.sort(b);
    out = newArray(0);
    for (i = 0; i < b.length; i++)
        if (i == 0 || b[i] != b[i - 1]) out = Array.concat(out, b[i]);
    return out;
}

function fmt(v) {
    if (isNaN(v)) return "";
    return d2s(v, 4);
}

function arrMean(a) {
    if (a.length == 0) return NaN;
    t = 0;
    for (i = 0; i < a.length; i++) t += a[i];
    return t / a.length;
}

function arrSD(a) {
    if (a.length < 2) return NaN;
    m = arrMean(a);
    t = 0;
    for (i = 0; i < a.length; i++) t += (a[i] - m) * (a[i] - m);
    return sqrt(t / (a.length - 1));
}

function summarize() {
    n = Table.size(gTbl);
    if (n == 0) return;
    metrics = newArray(gRatioA, gRatioB, "spindle_length_um");
    nm = metrics.length;
    conds = newArray(n);
    reps = newArray(n);
    keys = newArray(n);
    for (r = 0; r < n; r++) {
        conds[r] = "" + Table.getString("condition", r, gTbl);
        reps[r] = "" + Table.getString("replicate", r, gTbl);
        keys[r] = conds[r] + "\t" + reps[r];
    }
    uKeys = unique(keys);
    uConds = unique(conds);
    uReps = unique(reps);

    // ---- per condition x replicate
    repMean = newArray(uKeys.length * nm);
    s = "condition,replicate,n_cells";
    for (m = 0; m < nm; m++) s = s + "," + metrics[m] + "_mean," + metrics[m] + "_SD";
    s = s + "\n";
    for (k = 0; k < uKeys.length; k++) {
        kk = split(uKeys[k], "\t");
        nCell = 0;
        for (r = 0; r < n; r++) if (keys[r] == uKeys[k]) nCell++;
        line = kk[0] + "," + kk[1] + "," + nCell;
        for (m = 0; m < nm; m++) {
            vals = newArray(0);
            for (r = 0; r < n; r++)
                if (keys[r] == uKeys[k]) {
                    v = Table.get(metrics[m], r, gTbl);
                    if (!isNaN(v)) vals = Array.concat(vals, v);
                }
            repMean[k * nm + m] = arrMean(vals);
            line = line + "," + fmt(arrMean(vals)) + "," + fmt(arrSD(vals));
        }
        s = s + line + "\n";
    }
    File.saveString(s, gRoot + gOut + "_per_replicate.csv");

    // ---- per condition: mean of replicate means, and mean of all cells
    s = "condition,n_replicates,n_cells";
    for (m = 0; m < nm; m++)
        s = s + "," + metrics[m] + "_mean_of_replicates," + metrics[m] + "_SD_of_replicates," +
            metrics[m] + "_mean_all_cells," + metrics[m] + "_SD_all_cells";
    s = s + "\n";
    print("\n=== Per condition: mean of replicate means (SD) ===");
    for (c = 0; c < uConds.length; c++) {
        nRep = 0;
        for (k = 0; k < uKeys.length; k++) if (startsWith(uKeys[k], uConds[c] + "\t")) nRep++;
        nCell = 0;
        for (r = 0; r < n; r++) if (conds[r] == uConds[c]) nCell++;
        line = uConds[c] + "," + nRep + "," + nCell;
        msg = uConds[c] + " (" + nRep + " replicates, " + nCell + " cells):";
        for (m = 0; m < nm; m++) {
            rv = newArray(0);
            for (k = 0; k < uKeys.length; k++)
                if (startsWith(uKeys[k], uConds[c] + "\t")) {
                    v = repMean[k * nm + m];
                    if (!isNaN(v)) rv = Array.concat(rv, v);
                }
            cv = newArray(0);
            for (r = 0; r < n; r++)
                if (conds[r] == uConds[c]) {
                    v = Table.get(metrics[m], r, gTbl);
                    if (!isNaN(v)) cv = Array.concat(cv, v);
                }
            line = line + "," + fmt(arrMean(rv)) + "," + fmt(arrSD(rv)) + "," + fmt(arrMean(cv)) + "," + fmt(arrSD(cv));
            msg = msg + "   " + metrics[m] + " = " + d2s(arrMean(rv), 3);
            if (rv.length > 1) msg = msg + " (" + d2s(arrSD(rv), 3) + ")";
        }
        s = s + line + "\n";
        print(msg);
    }
    File.saveString(s, gRoot + gOut + "_per_condition.csv");

    // ---- Prism-ready: one file per ratio, rows = replicates, columns = conditions
    for (m = 0; m < 2; m++) {
        s = "replicate";
        for (c = 0; c < uConds.length; c++) s = s + "," + uConds[c];
        s = s + "\n";
        for (q = 0; q < uReps.length; q++) {
            line = uReps[q];
            for (c = 0; c < uConds.length; c++) {
                val = "";
                for (k = 0; k < uKeys.length; k++)
                    if (uKeys[k] == uConds[c] + "\t" + uReps[q]) val = fmt(repMean[k * nm + m]);
                line = line + "," + val;
            }
            s = s + line + "\n";
        }
        if (m == 0) chName = gNameA; else chName = gNameB;
        File.saveString(s, gRoot + gOut + "_prism_" + chName + ".csv");
    }
    print("Summaries saved in " + gRoot);
}
