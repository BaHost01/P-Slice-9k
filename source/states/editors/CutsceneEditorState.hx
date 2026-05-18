package states.editors;

import backend.StageData;
import objects.Character;
import haxe.Json;

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
	
	var camEditor:FlxCamera;
	var camHUD:FlxCamera;
	var UI_box:PsychUIBox;
	
	var curTime:Float = 0;
	var timelineText:FlxText;
	
	override function create()
	{
		camEditor = new FlxCamera();
		camHUD = new FlxCamera();
		camHUD.bgColor.alpha = 0;
		FlxG.cameras.add(camEditor);
		FlxG.cameras.add(camHUD, false);
		
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
		// Basic stage loading logic (background, etc.)
		var bg:FlxSprite = new FlxSprite(-600, -200).loadGraphic(Paths.image('stageback'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0.9, 0.9);
		add(bg);
		
		var stageFront:FlxSprite = new FlxSprite(-650, 600).loadGraphic(Paths.image('stagefront'));
		stageFront.setGraphicSize(Std.int(stageFront.width * 1.1));
		stageFront.updateHitbox();
		stageFront.antialiasing = ClientPrefs.data.antialiasing;
		stageFront.scrollFactor.set(0.9, 0.9);
		add(stageFront);
	}
	
	function addEditorUI()
	{
		UI_box = new PsychUIBox(FlxG.width - 320, 20, 300, 400, ["Characters", "Timeline"]);
		UI_box.cameras = [camHUD];
		add(UI_box);
		
		timelineText = new FlxText(20, FlxG.height - 40, 0, "Time: 0.00s", 24);
		timelineText.cameras = [camHUD];
		add(timelineText);
		
		addCharactersTab();
	}
	
	function addCharactersTab()
	{
		var tab = UI_box.getTab("Characters");
		
		var charInput = new PsychUIInputText(20, 30, 100, "bf", 8);
		var addBtn = new PsychUIButton(20, 60, "Add Character", function() {
			spawnCharacter("char_" + cutsceneData.characters.length, charInput.text, 0, 0, false);
		});
		
		tab.menu.add(new FlxText(20, 10, 0, "Character Name:"));
		tab.menu.add(charInput);
		tab.menu.add(addBtn);
	}
	
	function spawnCharacter(name:String, char:String, x:Float, y:Float, isPlayer:Bool)
	{
		var newChar:Character = new Character(x, y, char, isPlayer);
		characters.add(newChar);
		charMap.set(name, newChar);
		cutsceneData.characters.push({name: name, char: char, x: x, y: y, isPlayer: isPlayer});
	}
	
	override function update(elapsed:Float)
	{
		super.update(elapsed);
		
		if (FlxG.keys.justPressed.SPACE)
		{
			// Play/Pause timeline
		}
		
		if (controls.BACK)
		{
			MusicBeatState.switchState(new MasterEditorMenu());
		}
		
		timelineText.text = "Time: " + FlxMath.roundDecimal(curTime, 2) + "s";
	}
}
