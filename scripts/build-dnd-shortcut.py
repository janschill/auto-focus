"""Builds and signs the "Auto-Focus Do Not Disturb" shortcut bundled with the app.

Usage: python3 -I scripts/build-dnd-shortcut.py <output.shortcut>
Signing uses `shortcuts sign`, which requires a Mac signed into iCloud.


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
            "WFWorkflowActionParameters": {
                "UUID": u(),
                "WFOutput": {"Value": {"string": text, "attachmentsByRange": {}},
                             "WFSerializationType": "WFTextTokenString"}}}

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
    "WFWorkflowClientVersion": "3218.0.4.100",
    "WFWorkflowHasOutputFallback": False,
    "WFWorkflowHasShortcutInputVariables": True,
    "WFWorkflowIcon": {"WFWorkflowIconGlyphNumber": 61532, "WFWorkflowIconStartColor": 2846468607},
    "WFWorkflowImportQuestions": [],
    "WFWorkflowInputContentItemClasses": ["WFStringContentItem", "WFGenericFileContentItem"],
    "WFWorkflowMinimumClientVersion": 900,
    "WFWorkflowMinimumClientVersionString": "900",
    "WFWorkflowOutputContentItemClasses": ["WFStringContentItem"],
    "WFWorkflowTypes": [],
}
with tempfile.TemporaryDirectory() as tmp:
    unsigned = os.path.join(tmp, "unsigned.shortcut")
    with open(unsigned, "wb") as f:
        plistlib.dump(workflow, f, fmt=plistlib.FMT_BINARY)
    subprocess.run(["shortcuts", "sign", "--mode", "anyone", "--input", unsigned, "--output", sys.argv[1]], check=True)
