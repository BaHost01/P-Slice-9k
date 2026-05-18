package states.editors;

import backend.StageData;
import backend.StageData.StageFile;
import objects.Character;
import haxe.Json;
import openfl.net.FileReference;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import flash.net.FileFilter;
import sys.io.File;
import mikolka.stages.cutscenes.dialogueBox.DialogueBoxPsych;
import mikolka.stages.cutscenes.dialogueBox.DialogueBoxPsych.DialogueFile;
import mikolka.stages.cutscenes.dialogueBox.DialogueBoxPsych.DialogueLine;
import states.editors.content.FileDialogHandler;
import states.editors.content.Prompt;

typedef CutsceneData = {
	var stage:String;
	var characters:Array<CutsceneCharacter>;
	var keyframes:Array<CutsceneKeyframe>;
}

typedef CutsceneCharacter = {
	var name:String;
	var char:String;
	var x:Float;
	var y:Float;
	var isPlayer:Bool;
}

typedef CutsceneKeyframe = {
	var time:Float;
	var charName:String;
	var type:String; // "animation", "position", "camera", "dialogue"
	var value1:Dynamic;
	var value2:Dynamic;
}

class CutsceneEditorState extends MusicBeatState
{
	var characters:FlxTypedGroup<Character>;
	var charMap:Map<String, Character> = new Map<String, Character>();
	var cutsceneData:CutsceneData;
	var stageObjects:Array<FlxBasic> = [];
	
	var camEditor:FlxCamera;
	var camHUD:FlxCamera;
	var UI_box:PsychUIBox;
	var fileDialog:FileDialogHandler = new FileDialogHandler();
	var _file:FileReference;
	var selectedCharName:String = null;
	
	var curTime:Float = 0;
	var timelineText:FlxText;
	var stageInput:PsychUIInputText;
	var charInput:PsychUIInputText;
	var keyframeCharInput:PsychUIInputText;
	var keyframeTypeInput:PsychUIInputText;
	var keyframeValue1Input:PsychUIInputText;
	var keyframeValue2Input:PsychUIInputText;
	var playPreview:Bool = false;
	var previewIndex:Int = 0;
	var previewElapsed:Float = 0;
	var selectedKeyframeIndex:Int = -1;
	var dialoguePreview:DialogueBoxPsych = null;
	
	override function create()
	{
		CacheSystem.clearStoredMemory();
		CacheSystem.clearUnusedMemory();

		camEditor = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camEditor, false);
		FlxG.cameras.add(camHUD, false);
		FlxG.camera = camEditor;
		
		characters = new FlxTypedGroup<Character>();
		add(characters);
		
		cutsceneData = {
			stage: 'stage',
			characters: [],
			keyframes: []
		};
		
		loadStage(cutsceneData.stage);
		
		addEditorUI();
		
		FlxG.mouse.visible = true;
		super.create();
	}
	
	function loadStage(stage:String)
	{
		for (obj in stageObjects)
			if (obj != null) remove(obj, true);
		stageObjects = [];

		for (char in charMap)
			if (char != null) remove(char, true);
		charMap.clear();
		characters.clear();

		cutsceneData.stage = stage;
		var stageFile:StageFile = StageData.getStageFile(stage);
		StageData.forceNextDirectory = (stageFile != null) ? stageFile.directory : '';
		if (stageFile != null && stageFile.objects != null)
		{
			var loaded = StageData.addObjectsToState(stageFile.objects, null, null, null, null, true);
			for (key => spr in loaded)
			{
				stageObjects.push(spr);
				add(spr);
			}
		}
	}
	
	function addEditorUI()
	{
		UI_box = new PsychUIBox(FlxG.width - 340, 20, 320, 420, ["Characters", "Timeline", "File"]);
		UI_box.cameras = [camHUD];
		add(UI_box);
		
		timelineText = new FlxText(20, FlxG.height - 40, 0, "Time: 0.00s", 24);
		timelineText.cameras = [camHUD];
		add(timelineText);
		
		addCharactersTab();
		addTimelineTab();
		addFileTab();
	}
	
	function addCharactersTab()
	{
		var tab = UI_box.getTab("Characters");
		
		charInput = new PsychUIInputText(20, 30, 100, "bf", 32);
		var addBtn = new PsychUIButton(20, 60, "Add Character", function() {
			spawnCharacter("char_" + cutsceneData.characters.length, charInput.text, 0, 0, false);
		});
		var selectBtn = new PsychUIButton(140, 60, "Select First", function() {
			if (cutsceneData.characters.length > 0)
				selectedCharName = cutsceneData.characters[0].name;
		});
		
		tab.menu.add(new FlxText(20, 10, 0, "Character Name:"));
		tab.menu.add(charInput);
		tab.menu.add(addBtn);
		tab.menu.add(selectBtn);
		tab.menu.add(new FlxText(20, 95, 0, "Arrows move selected character.\nSHIFT speeds up."));
	}

	function addFileTab()
	{
		var tab = UI_box.getTab("File");
		stageInput = new PsychUIInputText(20, 30, 120, cutsceneData.stage, 32);
		var loadStageBtn = new PsychUIButton(20, 60, "Load Stage", function() {
			loadStage(stageInput.text.trim().length > 0 ? stageInput.text.trim() : 'stage');
		});
		var saveBtn = new PsychUIButton(20, 100, "Save JSON", saveCutscene);
		var exportBtn = new PsychUIButton(20, 140, "Export Runtime", exportRuntimeCutscene);
		var loadBtn = new PsychUIButton(20, 180, "Load JSON", openCutscene);

		tab.menu.add(new FlxText(20, 10, 0, "Stage:"));
		tab.menu.add(stageInput);
		tab.menu.add(loadStageBtn);
		tab.menu.add(saveBtn);
		tab.menu.add(exportBtn);
		tab.menu.add(loadBtn);
	}

	function addTimelineTab()
	{
		var tab = UI_box.getTab("Timeline");
		keyframeCharInput = new PsychUIInputText(20, 30, 120, "", 32);
		keyframeTypeInput = new PsychUIInputText(160, 30, 120, "animation", 32);
		keyframeValue1Input = new PsychUIInputText(20, 70, 260, "", 64);
		keyframeValue2Input = new PsychUIInputText(20, 110, 260, "", 64);
		var addKeyframeBtn = new PsychUIButton(20, 150, "Add Keyframe", addKeyframeAtPlayhead);
		var updateKeyframeBtn = new PsychUIButton(160, 150, "Update Selected", updateSelectedKeyframe);
		var playBtn = new PsychUIButton(20, 190, "Play Preview", startPreview);
		var stopBtn = new PsychUIButton(160, 190, "Stop Preview", stopPreview);
		var backBtn = new PsychUIButton(20, 230, "Step -0.1", function() curTime = Math.max(0, curTime - 0.1));
		var forwardBtn = new PsychUIButton(160, 230, "Step +0.1", function() curTime += 0.1);
		var prevKeyframeBtn = new PsychUIButton(20, 270, "Prev Keyframe", selectPrevKeyframe);
		var nextKeyframeBtn = new PsychUIButton(160, 270, "Next Keyframe", selectNextKeyframe);
		var deleteKeyframeBtn = new PsychUIButton(20, 310, "Delete Keyframe", deleteSelectedKeyframe);
		var clearBtn = new PsychUIButton(160, 310, "Clear Keyframes", function() { cutsceneData.keyframes = []; previewIndex = 0; selectedKeyframeIndex = -1; stopDialoguePreview(); });

		tab.menu.add(new FlxText(20, 10, 0, "Char / Type:"));
		tab.menu.add(keyframeCharInput);
		tab.menu.add(keyframeTypeInput);
		tab.menu.add(new FlxText(20, 55, 0, "Value 1:"));
		tab.menu.add(keyframeValue1Input);
		tab.menu.add(new FlxText(20, 95, 0, "Value 2:"));
		tab.menu.add(keyframeValue2Input);
		tab.menu.add(addKeyframeBtn);
		tab.menu.add(updateKeyframeBtn);
		tab.menu.add(playBtn);
		tab.menu.add(stopBtn);
		tab.menu.add(backBtn);
		tab.menu.add(forwardBtn);
		tab.menu.add(prevKeyframeBtn);
		tab.menu.add(nextKeyframeBtn);
		tab.menu.add(deleteKeyframeBtn);
		tab.menu.add(clearBtn);
	}
	
	function spawnCharacter(name:String, char:String, x:Float, y:Float, isPlayer:Bool)
	{
		var newChar:Character = new Character(x, y, char, isPlayer);
		characters.add(newChar);
		charMap.set(name, newChar);
		cutsceneData.characters.push({name: name, char: char, x: x, y: y, isPlayer: isPlayer});
		selectedCharName = name;
	}

	function addKeyframeAtPlayhead()
	{
		var keyframe:CutsceneKeyframe = {
			time: curTime,
			charName: keyframeCharInput.text,
			type: keyframeTypeInput.text.trim().length > 0 ? keyframeTypeInput.text.trim() : "animation",
			value1: keyframeValue1Input.text,
			value2: keyframeValue2Input.text
		};
		cutsceneData.keyframes.push(keyframe);
		cutsceneData.keyframes.sort(function(a, b) return a.time < b.time ? -1 : a.time > b.time ? 1 : 0);
		previewIndex = 0;
		selectedKeyframeIndex = cutsceneData.keyframes.indexOf(keyframe);
		refreshKeyframeFields();
	}

	function saveCutscene()
	{
		var data:String = Json.stringify(cutsceneData, "\t");
		#if sys
		File.saveContent('${cutsceneData.stage}_cutscene.json', data);
		#else
		if (_file == null) _file = new FileReference();
		_file.save(data, '${cutsceneData.stage}_cutscene.json');
		#end
		refreshKeyframeFields();
	}

	function exportRuntimeCutscene()
	{
		var runtimeData:Dynamic = {
			stage: cutsceneData.stage,
			characters: cutsceneData.characters,
			timers: [for (frame in cutsceneData.keyframes) {
				time: frame.time,
				character: frame.charName,
				action: frame.type,
				value1: frame.value1,
				value2: frame.value2
			}],
			format: "pslice_cutscene_v1"
		};
		var data:String = Json.stringify(runtimeData, "\t");
		#if sys
		File.saveContent('${cutsceneData.stage}_cutscene_runtime.json', data);
		#else
		if (_file == null) _file = new FileReference();
		_file.save(data, '${cutsceneData.stage}_cutscene_runtime.json');
		#end
		refreshKeyframeFields();
	}

	function openCutscene()
	{
		fileDialog.open('cutscene.json', 'Load Cutscene JSON', [new FileFilter('JSON', 'json')], function() {
			try
			{
				var parsed:Dynamic = Json.parse(fileDialog.data);
				if (parsed != null && Reflect.hasField(parsed, 'stage'))
				{
					cutsceneData = cast parsed;
					stageInput.text = cutsceneData.stage;
					loadStage(cutsceneData.stage);
					stopPreview();
					selectedKeyframeIndex = -1;
					refreshKeyframeFields();
					for (char in cutsceneData.characters)
						spawnCharacter(char.name, char.char, char.x, char.y, char.isPlayer);
				}
			}
			catch (e:Dynamic) {}
		});
	}

	function selectPrevKeyframe()
	{
		if (cutsceneData.keyframes.length < 1) return;
		selectedKeyframeIndex = (selectedKeyframeIndex < 0) ? 0 : Math.max(0, selectedKeyframeIndex - 1);
		curTime = cutsceneData.keyframes[selectedKeyframeIndex].time;
		refreshKeyframeFields();
		stopDialoguePreview();
	}

	function selectNextKeyframe()
	{
		if (cutsceneData.keyframes.length < 1) return;
		selectedKeyframeIndex = (selectedKeyframeIndex < 0) ? 0 : Math.min(cutsceneData.keyframes.length - 1, selectedKeyframeIndex + 1);
		curTime = cutsceneData.keyframes[selectedKeyframeIndex].time;
		refreshKeyframeFields();
		stopDialoguePreview();
	}

	function deleteSelectedKeyframe()
	{
		if (selectedKeyframeIndex < 0 || selectedKeyframeIndex >= cutsceneData.keyframes.length) return;
		cutsceneData.keyframes.splice(selectedKeyframeIndex, 1);
		selectedKeyframeIndex = Math.min(selectedKeyframeIndex, cutsceneData.keyframes.length - 1);
		previewIndex = 0;
		stopDialoguePreview();
		refreshKeyframeFields();
	}

	function refreshKeyframeFields()
	{
		if (selectedKeyframeIndex < 0 || selectedKeyframeIndex >= cutsceneData.keyframes.length)
		{
			keyframeCharInput.text = "";
			keyframeTypeInput.text = "animation";
			keyframeValue1Input.text = "";
			keyframeValue2Input.text = "";
			return;
		}

		var frame = cutsceneData.keyframes[selectedKeyframeIndex];
		keyframeCharInput.text = frame.charName != null ? frame.charName : "";
		keyframeTypeInput.text = frame.type != null ? frame.type : "animation";
		keyframeValue1Input.text = Std.string(frame.value1 != null ? frame.value1 : "");
		keyframeValue2Input.text = Std.string(frame.value2 != null ? frame.value2 : "");
	}

	function updateSelectedKeyframe()
	{
		if (selectedKeyframeIndex < 0 || selectedKeyframeIndex >= cutsceneData.keyframes.length) return;

		var frame = cutsceneData.keyframes[selectedKeyframeIndex];
		frame.time = curTime;
		frame.charName = keyframeCharInput.text;
		frame.type = keyframeTypeInput.text.trim().length > 0 ? keyframeTypeInput.text.trim() : frame.type;
		frame.value1 = keyframeValue1Input.text;
		frame.value2 = keyframeValue2Input.text;
		cutsceneData.keyframes.sort(function(a, b) return a.time < b.time ? -1 : a.time > b.time ? 1 : 0);
		selectedKeyframeIndex = cutsceneData.keyframes.indexOf(frame);
		previewIndex = 0;
		refreshKeyframeFields();
	}

	function stopPreview()
	{
		playPreview = false;
		previewIndex = 0;
		previewElapsed = 0;
		curTime = 0;
	}

	function startPreview()
	{
		stopPreview();
		playPreview = true;
	}

	function stopDialoguePreview()
	{
		if (dialoguePreview != null)
		{
			remove(dialoguePreview, true);
			dialoguePreview.destroy();
			dialoguePreview = null;
		}
	}

	function showDialoguePreview(line:DialogueLine)
	{
		stopDialoguePreview();
		var dialogue:DialogueFile = {
			dialogue: [line],
			style: ""
		};
		dialoguePreview = new DialogueBoxPsych(dialogue);
		dialoguePreview.cameras = [camHUD];
		add(dialoguePreview);
	}

	function applyKeyframe(frame:CutsceneKeyframe)
	{
		if (frame == null) return;
		switch (frame.type)
		{
			case "position":
				if (frame.charName != null && charMap.exists(frame.charName))
				{
					var ch = charMap.get(frame.charName);
					var px = Std.parseFloat(Std.string(frame.value1));
					var py = Std.parseFloat(Std.string(frame.value2));
					if (!Math.isNaN(px)) ch.x = px;
					if (!Math.isNaN(py)) ch.y = py;
				}
			case "animation":
				if (frame.charName != null && charMap.exists(frame.charName))
				{
					var anim = Std.string(frame.value1);
					if (anim != null && anim.length > 0)
						charMap.get(frame.charName).playAnim(anim, true);
				}
			case "camera":
				var x = Std.parseFloat(Std.string(frame.value1));
				var y = Std.parseFloat(Std.string(frame.value2));
				if (!Math.isNaN(x)) camEditor.scroll.x = x;
				if (!Math.isNaN(y)) camEditor.scroll.y = y;
			case "dialogue":
				var line:DialogueLine = {
					portrait: frame.charName,
					expression: null,
					text: Std.string(frame.value1),
					boxState: Std.string(frame.value2 != null ? frame.value2 : "normal"),
					speed: 0.05
				};
				showDialoguePreview(line);
			default:
		}
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (playPreview)
		{
			previewElapsed += elapsed;
			curTime = previewElapsed;
			while (previewIndex < cutsceneData.keyframes.length && cutsceneData.keyframes[previewIndex].time <= curTime)
			{
				applyKeyframe(cutsceneData.keyframes[previewIndex]);
				previewIndex++;
			}
		}
		
		if (selectedCharName != null && charMap.exists(selectedCharName) && !playPreview)
		{
			var ch = charMap.get(selectedCharName);
			var move = FlxG.keys.pressed.SHIFT ? 10 : 1;
			if (FlxG.keys.pressed.LEFT) ch.x -= move;
			if (FlxG.keys.pressed.RIGHT) ch.x += move;
			if (FlxG.keys.pressed.UP) ch.y -= move;
			if (FlxG.keys.pressed.DOWN) ch.y += move;
			for (entry in cutsceneData.characters)
				if (entry.name == selectedCharName)
				{
					entry.x = ch.x;
					entry.y = ch.y;
					break;
				}
		}
		
		if (controls.BACK)
		{
			MusicBeatState.switchState(new MasterEditorMenu());
		}
		
		if (FlxG.keys.justPressed.SPACE)
		{
			if (playPreview) stopPreview();
			else startPreview();
		}

		if (FlxG.keys.justPressed.DELETE || FlxG.keys.justPressed.BACKSPACE)
			deleteSelectedKeyframe();

		timelineText.text = "Time: " + FlxMath.roundDecimal(curTime, 2) + "s | Keyframes: " + cutsceneData.keyframes.length + " | Selected: " + selectedKeyframeIndex;
	}
}
