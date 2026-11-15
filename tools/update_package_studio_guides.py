from pathlib import Path
from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.shared import Inches, Pt, RGBColor

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
HELP = ROOT / "Help"
SHOTS = DOCS / "screenshots"
PSP_SHOTS = SHOTS / "PackageStudioPro"

BLUE = RGBColor(43, 95, 158)
DARK_BLUE = RGBColor(23, 63, 107)
MID_BLUE = RGBColor(36, 84, 134)
TEXT = RGBColor(31, 43, 58)
MUTED = RGBColor(70, 103, 137)
PALE = "EAF2FB"


def set_cell_shading(cell, fill):
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = cell._element.xpath("./w:tcPr/w:shd")
    if shd:
        shd[0].set("{http://schemas.openxmlformats.org/wordprocessingml/2006/main}fill", fill)
    else:
        from docx.oxml import OxmlElement
        shade = OxmlElement("w:shd")
        shade.set("{http://schemas.openxmlformats.org/wordprocessingml/2006/main}fill", fill)
        tc_pr.append(shade)


def apply_base_styles(doc):
    styles = doc.styles
    normal = styles["Normal"]
    normal.font.name = "Aptos"
    normal.font.size = Pt(10.5)
    normal.font.color.rgb = TEXT
    for name, size in [("Title", 24), ("Heading 1", 17), ("Heading 2", 13)]:
        style = styles[name]
        style.font.name = "Aptos Display" if name == "Title" else "Aptos"
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = DARK_BLUE if name != "Title" else BLUE


def setup_page(doc):
    section = doc.sections[0]
    section.top_margin = Inches(0.7)
    section.bottom_margin = Inches(0.65)
    section.left_margin = Inches(0.7)
    section.right_margin = Inches(0.7)


def title_page(doc, title, subtitle):
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run("Package Studio Pro")
    run.bold = True
    run.font.size = Pt(26)
    run.font.color.rgb = BLUE
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run(title)
    run.bold = True
    run.font.size = Pt(20)
    run.font.color.rgb = DARK_BLUE
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run(subtitle)
    run.font.size = Pt(12)
    run.font.color.rgb = MUTED
    doc.add_paragraph()
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run("Current build identity: PackageStudioPro.exe")
    run.font.size = Pt(11)
    run.font.color.rgb = TEXT
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run("Last revised: May 22, 2026")
    run.font.size = Pt(10)
    run.font.color.rgb = MUTED
    doc.add_page_break()


def add_callout(doc, title, body):
    table = doc.add_table(rows=1, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    cell = table.cell(0, 0)
    set_cell_shading(cell, PALE)
    p = cell.paragraphs[0]
    r = p.add_run(title + ": ")
    r.bold = True
    r.font.color.rgb = DARK_BLUE
    p.add_run(body)
    doc.add_paragraph()


def add_table(doc, headers, rows):
    table = doc.add_table(rows=1, cols=len(headers))
    table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    for i, header in enumerate(headers):
        cell = table.cell(0, i)
        set_cell_shading(cell, "2B5F9E")
        cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
        p = cell.paragraphs[0]
        r = p.add_run(header)
        r.bold = True
        r.font.color.rgb = RGBColor(255, 255, 255)
    for row in rows:
        cells = table.add_row().cells
        for i, value in enumerate(row):
            cells[i].vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            cells[i].text = value
    doc.add_paragraph()


def add_image(doc, path, caption):
    if path.exists():
        p = doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.add_run().add_picture(str(path), width=Inches(6.8))
        cp = doc.add_paragraph()
        cp.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = cp.add_run(caption)
        run.italic = True
        run.font.size = Pt(9)
        run.font.color.rgb = MUTED


def user_guide():
    doc = Document()
    setup_page(doc)
    apply_base_styles(doc)
    title_page(doc, "User Guide", "Step-by-step installer project creation, validation, build, and setup execution.")

    doc.add_heading("Overview", level=1)
    doc.add_paragraph(
        "Package Studio Pro creates Windows setup packages from a compiled application EXE and a Package Studio Pro project file. "
        "The current authoring workspace is divided into focused Product, Payload, Install, Integration, and Build & Review tabs."
    )
    add_image(doc, PSP_SHOTS / "psp-product-tab.png", "Product tab for source file, application EXE, product name, publisher, and version.")

    doc.add_heading("Required Information", level=1)
    add_table(doc, ["Field", "Required", "Purpose"], [
        ("Project source file", "Yes", "The Delphi project/source file used to infer product name and default project paths."),
        ("Application EXE", "Yes", "The compiled program that will be copied into the installer payload."),
        ("Product name", "Yes", "The display name used for folders, shortcuts, setup file naming, and reports."),
        ("Publisher", "Recommended", "The publisher shown in setup summaries and project metadata."),
        ("Version", "Yes", "The product version written into the project and setup summary."),
        ("Install folder", "Yes", "The destination folder for the installed application."),
        ("Build output folder", "Yes", "The folder where the setup EXE, payload, reports, and export ZIP are written."),
    ])

    doc.add_heading("Create a Setup Package", level=1)
    steps = [
        "Run C:\\Development\\Package Studio Pro\\bin\\PackageStudioPro.exe.",
        "Open the Product tab and click Browse Source File. Select the Delphi source/project file for the application.",
        "Confirm the product name. Package Studio Pro fills this from the selected source file name, such as MazeFMX to Maze FMX.",
        "Confirm Publisher and Version.",
        "Open the Payload tab. Add support files or folders that should be installed with the application.",
        "Open the Install tab. Confirm the install folder, shortcut options, and optional license text.",
        "Open the Integration tab only when the package needs environment variables, PATH entries, file associations, or HKCU registry entries.",
        "Open the Build & Review tab. Confirm the Project file and Build output folder. The output folder controls where the setup package is exported.",
        "Click Validate. Resolve any validation messages before building.",
        "Click Build Package. The final setup executable is named with the product token plus Setup.exe, such as MorseTrainerSetup.exe.",
    ]
    for step in steps:
        doc.add_paragraph(step, style="List Number")
    add_callout(doc, "Output naming", "A product named Morse Trainer exports as MorseTrainerSetup.exe. That setup executable is self-contained and includes the project manifest and payload files. The output folder also contains embedded-manifest.json, build-report.txt, safety-report.txt, WipRuntime.exe, and an export ZIP for review and automation.")

    doc.add_heading("Authoring Tabs", level=1)
    doc.add_paragraph("Each tab focuses on one part of the package so required fields, payload choices, installation behavior, integrations, and build review stay easy to scan.")
    add_image(doc, PSP_SHOTS / "psp-payload-tab.png", "Payload tab for adding support files and folders.")
    add_image(doc, PSP_SHOTS / "psp-install-tab.png", "Install tab for destination folder, shortcuts, and license text.")
    add_image(doc, PSP_SHOTS / "psp-integration-tab.png", "Integration tab for environment variables, PATH entries, file associations, and HKCU registry entries.")
    add_image(doc, PSP_SHOTS / "psp-build-review-tab.png", "Build & Review tab for output folder, summary, validation, and build messages.")

    doc.add_heading("Run the Exported Installer", level=1)
    doc.add_paragraph("After export, open the build output folder and run the generated setup executable, for example MorseTrainerSetup.exe.")
    add_image(doc, SHOTS / "PackageStudioPro_SetupWizard_Blue.png", "Runtime setup wizard generated by Package Studio Pro.")
    for step in [
        "Review the product, publisher, version, install folder, payload count, shortcuts, and license text.",
        "Click Install to install the application.",
        "Use Verify to confirm installed files have not changed.",
        "Use Repair to restore missing or changed files.",
        "Use Uninstall to remove files and owned per-user integration entries."
    ]:
        doc.add_paragraph(step, style="List Number")

    doc.add_heading("Optional Data", level=1)
    add_table(doc, ["Option", "When to use it"], [
        ("License text", "Use when the setup wizard should display an EULA or product notice."),
        ("Digital signing", "Use only when SignTool and a valid certificate are available."),
        ("Environment variables", "Use for per-user variables needed by the application."),
        ("PATH entries", "Use for per-user PATH folders that should be appended during install and removed or restored during uninstall. Use {app} for the install folder."),
        ("File associations", "Use when a file extension should open with the installed application."),
        ("Registry entries", "Use only for HKCU entries that you fully understand."),
        ("Prerequisites and features", "Use for metadata and setup notes, not machine-wide installation actions."),
    ])

    doc.add_heading("Safety Notes", level=1)
    doc.add_paragraph(
        "Package Studio Pro blocks unsafe output folders and protected install locations, limits registry integration to HKCU, "
        "writes a safety report, and maintains an install manifest for verify, repair, and uninstall."
    )
    doc.save(DOCS / "PackageStudioPro_UserGuide.docx")
    if HELP.exists():
        doc.save(HELP / "PackageStudioPro_UserGuide.docx")


def engineering_guide():
    doc = Document()
    setup_page(doc)
    apply_base_styles(doc)
    title_page(doc, "Engineering Guide", "Architecture, build process, UI assets, safety controls, and maintenance reference.")

    doc.add_heading("Introduction", level=1)
    doc.add_paragraph(
        "Package Studio Pro is a Delphi FMX installer authoring and runtime system. It includes a visible designer-backed authoring app, "
        "a tabbed authoring workspace, a package build tool, a setup runtime, and shared project/safety/install units."
    )
    add_image(doc, PSP_SHOTS / "psp-product-tab.png", "Authoring UI after the Package Studio Pro tabbed workspace update.")

    doc.add_heading("Current Project Layout", level=1)
    add_table(doc, ["Path", "Responsibility"], [
        ("src\\PackageStudioPro", "FMX authoring application, WizardForm.fmx, PackageStudioPro.dpr, and PackageStudioPro.dproj."),
        ("src\\SetupWizard", "FMX setup wizard runtime UI used by exported setup executables."),
        ("src\\SetupRuntime", "Console runtime entry point for install, verify, repair, and uninstall automation."),
        ("src\\WIPBuild", "Command-line exporter that validates projects, stages payloads, creates setup EXEs, reports, and export ZIPs."),
        ("src\\Shared", "TWipProject JSON model, TWipSafety validation, and TWipInstallEngine runtime operations."),
        ("tools", "Build and acceptance-test scripts."),
        ("docs", "User and engineering guides plus current screenshots."),
    ])

    doc.add_heading("Executable Identity", level=1)
    add_table(doc, ["Executable", "Purpose"], [
        ("PackageStudioPro.exe", "Main authoring application. Current Package Studio Pro authoring identity."),
        ("WIPBuild.exe", "Command-line build/export tool."),
        ("WipSetup.exe", "FMX setup wizard runtime copied and renamed into exported setup packages."),
        ("WipRuntime.exe", "Console runtime used for scripted install, verify, repair, and uninstall operations."),
    ])

    doc.add_heading("Build Flow", level=1)
    for item in [
        "Authoring UI or wizard writes a PackageStudioPro.Project.v1 .wiproj file.",
        "WIPBuild loads and validates the project through TWipSafety.",
        "WIPBuild cleans or creates a marked output folder and stages payload files under payload.",
        "WIPBuild copies WipSetup.exe to ProductTokenSetup.exe, such as MorseTrainerSetup.exe.",
        "WIPBuild writes embedded-manifest.json, build-report.txt, safety-report.txt, WipRuntime.exe, and the export ZIP, then embeds the install manifest and payload inside the generated setup executable."
    ]:
        doc.add_paragraph(item, style="List Number")

    doc.add_heading("Designer Forms", level=1)
    doc.add_paragraph(
        "The project intentionally uses visible .fmx forms. UI color changes are stored in the designer files so manual IDE edits remain visible."
    )
    add_image(doc, PSP_SHOTS / "psp-integration-tab.png", "Integration tab with dedicated PATH entries separate from environment variables.")
    add_image(doc, PSP_SHOTS / "psp-build-review-tab.png", "Build & Review tab with validation output and setup export controls.")

    doc.add_heading("Safety Model", level=1)
    add_table(doc, ["Guard", "Current behavior"], [
        ("Install folder guard", "Blocks drive roots, Windows, and System32 paths."),
        ("Output folder guard", "Blocks drive roots/protected folders and refuses unmarked non-empty folders."),
        ("Registry guard", "Allows HKCU only and rejects root/blank registry value names."),
        ("PATH guard", "Appends user PATH entries only, records manifest state, and restores/removes entries on uninstall."),
        ("Payload guard", "Verifies files exist and prevents target-name collisions in the staged payload tree."),
        ("Manifest", "Writes PackageStudioPro.install-manifest for verify, repair, and uninstall."),
        ("Signing", "Requires explicit SignTool path and certificate when enabled."),
    ])

    doc.add_heading("Verification", level=1)
    doc.add_paragraph("The current build was compiled with tools\\build_all.ps1 after the Package Studio Pro tabbed workspace and PATH-entry update.")
    doc.add_paragraph("The acceptance suite exercises build, install, verify, tamper detection, repair, uninstall, protected-folder blocking, tree payload export, and PATH entry cleanup.")

    doc.add_heading("Maintenance Notes", level=1)
    doc.add_paragraph(
        "When changing forms, edit WizardForm.fmx or SetupForm.fmx in the IDE or directly with care. "
        "Avoid adding runtime layout code that hides designer state unless a specific defect requires it."
    )
    doc.save(DOCS / "PackageStudioPro_EngineeringGuide.docx")
    if HELP.exists():
        doc.save(HELP / "PackageStudioPro_EngineeringGuide.docx")


if __name__ == "__main__":
    user_guide()
    engineering_guide()
    print("GUIDES_UPDATED")
