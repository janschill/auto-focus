"""Builds and signs the "Auto-Focus Do Not Disturb" shortcut bundled with the app.

Usage: python3 -I scripts/build-dnd-shortcut.py [--unsigned] <output.shortcut>
Signing uses `shortcuts sign`, which requires a Mac signed into iCloud. --unsigned writes the
plain workflow plist instead, for comparing against the shipped shortcut.

The generated workflow matches the shipped shortcut, which was built in the Shortcuts app and
checked by hand. Apart from action UUIDs, a rebuilt shortcut should not differ from it.

Input: text "on" or "off" (passed as a file by `shortcuts run --input-path`).
on:  if any Focus is already active -> output "already-active" (leave it alone)
     else turn Do Not Disturb on      -> output "enabled"
off: turn Do Not Disturb off          -> output "disabled"
anything else: change nothing         -> output "unknown-input"
"""
import os, plistlib, subprocess, sys, tempfile, uuid

def u(): return str(uuid.uuid4()).upper()

FOCUS_UUID, TEXT_UUID = u(), u()
IS_ON, HAS_FOCUS, IS_OFF = u(), u(), u()

def var(output_uuid, output_name):
    return {"Value": {"OutputUUID": output_uuid, "OutputName": output_name, "Type": "ActionOutput"},
            "WFSerializationType": "WFTextTokenAttachment"}

def cond_input(output_uuid, output_name):
    return {"Type": "Variable", "Variable": var(output_uuid, output_name)}

def output(text):
    return {"WFWorkflowActionIdentifier": "is.workflow.actions.output",
            "WFWorkflowActionParameters": {"UUID": u(), "WFOutput": text}}

def ctrl(group, mode, extra=None):
    params = {"GroupingIdentifier": group, "WFControlFlowMode": mode}
    params.update(extra or {})
    return {"WFWorkflowActionIdentifier": "is.workflow.actions.conditional", "WFWorkflowActionParameters": params}

actions = [
    {"WFWorkflowActionIdentifier": "is.workflow.actions.dnd.getfocus",
     "WFWorkflowActionParameters": {"UUID": FOCUS_UUID}},
    {"WFWorkflowActionIdentifier": "is.workflow.actions.detect.text",
     "WFWorkflowActionParameters": {"UUID": TEXT_UUID,
         "WFInput": {"Value": {"Type": "ExtensionInput"}, "WFSerializationType": "WFTextTokenAttachment"}}},
    # If Text is "on"
    ctrl(IS_ON, 0, {"WFCondition": 4, "WFConditionalActionString": "on",
                    "WFInput": cond_input(TEXT_UUID, "Text")}),
        # If Current Focus has any value
        ctrl(HAS_FOCUS, 0, {"WFCondition": 100, "WFInput": cond_input(FOCUS_UUID, "Current Focus")}),
            output("already-active"),
        ctrl(HAS_FOCUS, 1),
            {"WFWorkflowActionIdentifier": "is.workflow.actions.dnd.set",
             "WFWorkflowActionParameters": {"Enabled": 1}},
            output("enabled"),
        ctrl(HAS_FOCUS, 2, {"UUID": u()}),
    ctrl(IS_ON, 1),
        # If Text is "off"
        ctrl(IS_OFF, 0, {"WFCondition": 4, "WFConditionalActionString": "off",
                         "WFInput": cond_input(TEXT_UUID, "Text")}),
            {"WFWorkflowActionIdentifier": "is.workflow.actions.dnd.set", "WFWorkflowActionParameters": {}},
            output("disabled"),
        ctrl(IS_OFF, 1),
            output("unknown-input"),
        ctrl(IS_OFF, 2, {"UUID": u()}),
    ctrl(IS_ON, 2, {"UUID": u()}),
]

workflow = {
    "WFQuickActionSurfaces": [],
    "WFWorkflowActions": actions,
    "WFWorkflowClientVersion": "5037.111",
    "WFWorkflowHasOutputFallback": False,
    "WFWorkflowHasShortcutInputVariables": True,
    "WFWorkflowIcon": {"WFWorkflowIconGlyphNumber": 61440, "WFWorkflowIconStartColor": 946986751},
    "WFWorkflowImportQuestions": [],
    "WFWorkflowInputContentItemClasses": ["WFAppContentItem", "WFGenericFileContentItem", "WFStringContentItem"],
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowOutputContentItemClasses": ["WFStringContentItem"],
    "WFWorkflowTypes": [],
}

args = sys.argv[1:]
unsigned_only = "--unsigned" in args
paths = [arg for arg in args if arg != "--unsigned"]
if len(paths) != 1:
    sys.exit(__doc__)

if unsigned_only:
    with open(paths[0], "wb") as f:
        plistlib.dump(workflow, f, fmt=plistlib.FMT_BINARY)
else:
    with tempfile.TemporaryDirectory() as tmp:
        unsigned = os.path.join(tmp, "unsigned.shortcut")
        with open(unsigned, "wb") as f:
            plistlib.dump(workflow, f, fmt=plistlib.FMT_BINARY)
        subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", unsigned, "--output", paths[0]], check=True)
