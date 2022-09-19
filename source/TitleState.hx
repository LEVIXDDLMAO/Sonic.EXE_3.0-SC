package;

#if DISCORD_ALLOWED
import Discord.DiscordClient;
#end
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.keyboard.FlxKey;
import flixel.system.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import haxe.Json;
import lime.app.Application;
import openfl.utils.Assets;
#if CHECK_FOR_UPDATES
import haxe.Http;
#end

using StringTools;

class TitleState extends MusicBeatState
{
	public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
	public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
	public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];

	public static var initialized:Bool = false;

	var blackScreen:FlxSprite;
	var credGroup:FlxGroup;

	override public function create():Void
	{
		Paths.clearStoredMemory();
		Paths.clearUnusedMemory();
		Application.current.window.title = "Sonic.EXE 2.5/3.0";
		
		// Just to load a mod on start up if ya got one. For mods that change the menu music and bg
		WeekData.loadTheFirstEnabledMod();

		FlxG.game.focusLostFramerate = 60;
		FlxG.sound.muteKeys = muteKeys;
		FlxG.sound.volumeDownKeys = volumeDownKeys;
		FlxG.sound.volumeUpKeys = volumeUpKeys;
		FlxG.keys.preventDefaultKeys = [TAB];

		PlayerSettings.init();

		super.create();

		FlxG.save.bind('funkin', 'extra');

		ClientPrefs.loadPrefs();

		Highscore.load();

		if (!initialized && FlxG.save.data != null && FlxG.save.data.fullscreen)
		{
			FlxG.fullscreen = FlxG.save.data.fullscreen;
		}

		if (FlxG.save.data.weekCompleted != null)
		{
			StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;
		}

		if (FlxG.save.data.lastPlayed != null) {
			FreeplayState.lastPlayed = FlxG.save.data.lastPlayed;
		}

		FlxG.mouse.visible = false;
		if (FlxG.save.data.flashing == null && !FlashingState.leftState) {
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
			MusicBeatState.switchState(new FlashingState());
		} else {
			#if DISCORD_ALLOWED
			if (!DiscordClient.isInitialized)
			{
				DiscordClient.initialize();
				Application.current.onExit.add (function (exitCode) {
					DiscordClient.shutdown();
				});
			}
			#end
			
			new FlxTimer().start(1, function(tmr:FlxTimer)
			{
				startIntro();
			});
		}
	}

	var logoBl:FlxSprite;
	var logoBlBUMP:FlxSprite;
	var titleText:FlxSprite;
	var bg:FlxSprite;

	function startIntro()
	{
		if (!initialized)
		{
			if (FlxG.sound.music == null) {
				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);

				FlxG.sound.music.fadeIn(4, 0, 0.7);

				Conductor.changeBPM(190);
			}
		}

		persistentUpdate = true;

		bg = new FlxSprite(0, 0);
		bg.frames = Paths.getSparrowAtlas('title/NewTitleMenuBG');
		bg.animation.addByPrefix('idle', "TitleMenuSSBG instance 1", 24);
		bg.animation.play('idle');
		bg.alpha = .75;
		bg.scale.x = 3;
		bg.scale.y = 3;
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		logoBlBUMP = new FlxSprite(0, 0);
		logoBlBUMP.loadGraphic(Paths.image('title/Logo'));
		logoBlBUMP.antialiasing = ClientPrefs.globalAntialiasing;

		logoBlBUMP.scale.x = .5;
		logoBlBUMP.scale.y = .5;

		logoBlBUMP.screenCenter();

		add(logoBlBUMP);

		titleText = new FlxSprite(0, 0);
		titleText.frames = Paths.getSparrowAtlas('title/titleEnterNEW');
		titleText.animation.addByPrefix('idle', "Press Enter to Begin instance 1", 24);
		titleText.animation.addByPrefix('press', "ENTER PRESSED instance 1", 24, false);
		titleText.antialiasing = ClientPrefs.globalAntialiasing;
		titleText.animation.play('idle');
		titleText.updateHitbox();
		titleText.screenCenter();
		// titleText.screenCenter(X);
		add(titleText);

		blackScreen = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(blackScreen);

		if (Assets.exists(Paths.sound(TitleLaugh))) {
			FlxG.sound.play(Paths.sound('TitleLaugh'), 1, false, null, false, function()
			{
				skipIntro();
			});
		}
		else skipIntro();
	}

	var transitioning:Bool = false;

	override function update(elapsed:Float)
	{
		if (FlxG.sound.music != null)
			Conductor.songPosition = FlxG.sound.music.time;

		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER || controls.ACCEPT || FlxG.mouse.justPressed;

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (touch.justPressed)
			{
				pressedEnter = true;
			}
		}
		#end

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}

		if (initialized && !transitioning && skippedIntro)
		{
			if (pressedEnter)
			{
				if (titleText != null) titleText.animation.play('press');

				FlxG.camera.flash(FlxColor.WHITE, 1);
				FlxG.sound.play(Paths.sound('confirmMenu'), 0.7);

				transitioning = true;

				new FlxTimer().start(0.3, function(tmr:FlxTimer)
				{
					MusicBeatState.switchState(new MainMenuState());
				});
			}
		}

		if (initialized && pressedEnter && !skippedIntro)
		{
			skipIntro();
		}

		super.update(elapsed);
	}

	function playBoop1()
	{
		if (!skippedIntro)
		{
			FlxG.sound.play(Paths.sound('boop1', 'shared'));
		}
	}

	function playBoop2()
	{
		if (!skippedIntro)
		{
			FlxG.sound.play(Paths.sound('boop2', 'shared'));
		}
	}

	function playShow()
	{
		if (!skippedIntro)
		{
			FlxG.sound.play(Paths.sound('showMoment', 'shared'), .4);
		}
	}

	override function beatHit()
	{
		super.beatHit();
	}

	var skippedIntro:Bool = false;
	function skipIntro():Void
	{
		if (!skippedIntro)
		{
			FlxG.sound.play(Paths.sound('showMoment', 'shared'), .4);

			FlxG.camera.flash(FlxColor.RED, 2);
			skippedIntro = true;
			remove(blackScreen);
		}
	}
}
