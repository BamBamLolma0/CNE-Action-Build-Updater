//a
import funkin.menus.BetaWarningState;
import funkin.editors.ui.UIState;
import funkin.backend.MusicBeatState;

import funkin.backend.system.macros.GitCommitMacro;
import funkin.backend.utils.HttpUtil;

import funkin.backend.system.Conductor;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import funkin.backend.utils.NativeAPI;
import funkin.backend.utils.NativeAPI.FileAttribute;
import funkin.backend.utils.FileAttribute;

import funkin.options.OptionsMenu;

import Sys;
import Type;
import StringTools;

var url = "https://api.github.com/repos/CodenameCrew/CodenameEngine/branches/main";
var needsUpdate = false;
var moveFiles = false;
var args = [];

function new() {
    // OptionsMenu.mainOptions.push({
    //     name: 'Auto Action Updater >',
    //     desc: 'Settings for the Auto Action Updater',
    //     state: new OptionsScreen(name, desc, parseOptionsFromXML(node))
    // });
    FlxG.save.data.autoUpdate ??= true;
    FlxG.save.flush();
    var temp = [];
    for (arg in Sys.args()) {
        if (StringTools.startsWith(arg, "/")) temp.push('-'+arg.substr(1))
        else temp.push(arg);
    }
    args = temp;

    if (args.contains('update')) {
        moveFiles = MusicBeatState.skipTransOut = MusicBeatState.skipTransIn = true;
        return;
    }
    CoolUtil.deleteFolder('./.cache');
    CoolUtil.safeAddAttributes('./.cache/', FileAttribute.HIDDEN); // 0x2
    if (FileSystem.exists("temp.exe")) FileSystem.deleteFile('temp.exe');
    if (FlxG.save.data.autoUpdate) needsUpdate = checkActionUpdates();
}

static var updater_currentGithubHash = null;
static var updater_data = null;
static function checkActionUpdates() {
    var http = null;
    try {
        http = Json.parse(HttpUtil.requestText(url));
        updater_data = http;
        currentGithubHash = http.commit.sha;
    } catch(e:Error) { trace("Failed to get current github hash"); }
    trace("checking...");
    if (currentGithubHash == null || StringTools.startsWith(currentGithubHash, GitCommitMacro.commitHash)) return false;
    return true;
}

function preStateSwitch() {
    stopPlayingSong = false;
    if (moveFiles) {
        FlxG.game._requestedState = new ModState("update.MovingFiles");
        return;
    }
    if (!needsUpdate) return;
    if (!(FlxG.game._requestedState is BetaWarningState)) return;
    
    FlxG.save.data.autoUpdate ??= true;
    FlxG.save.data.osChoice ??= "Windows";
    FlxG.save.flush();

    needsUpdate = false;
    FlxG.game._requestedState = new UIState(true, "update.ActionBuildsUpdater");
}


function destroy() {
    stopPlayingSong = funny_playSong = updater_data = updater_currentGithubHash = checkActionUpdates = null;
}

var allSongs = Paths.getFolderContent("music/updateMusic");
var temp = [];
for (song in allSongs) temp.push(Path.withoutExtension(song));
allSongs = temp;

public static var stopPlayingSong = false;

var timeFadeOut = 5;
var time = -1;

var lastRandomInt:Int = -1;
public static function funny_playSong() {
    if (stopPlayingSong) return;
    
    var ary = (lastRandomInt == -1) ? [] : [lastRandomInt];
    var rngInt = lastRandomInt = FlxG.random.int(0, allSongs.length-1, ary);
	var randomSong = allSongs[rngInt];
    FlxG.sound.playMusic(Paths.music("updateMusic/"+randomSong), 0.4, false);
    FlxG.sound.volume = 0.4;
    time = 0;
}

function update(elapsed:Float) {
    if (FlxG.sound.music == null) return;
    if (time < 0 && !stopPlayingSong) return;
    time = FlxG.sound.music.time*0.001;
    if (time <= (FlxG.sound.music.length*0.001 - timeFadeOut)) return;
    // trace("FADE OUT!!!!");
    time = -1;
    new FlxTimer().start(timeFadeOut, funny_playSong); // onComplete was buggin for fade out, so force it anyways.
}

var prev_volume:Float = 0;
var lostFocus:Bool = false;
var stopVolume:Bool = true;

var noFocusVolume = 0.2;
function focusLost() {
    if (FlxG.autoPause) return;
    if (!FlxG?.sound?.music?.playing) return;
    stopVolume = false;
    lostFocus = true;
    prev_volume = FlxG?.sound?.music?.volume;
    FlxG?.sound?.music?.fadeOut(1, noFocusVolume);
}

function focusGained() {
    if (FlxG.autoPause) return;
    if (!FlxG?.sound?.music?.playing) return;
    lostFocus = false;
    FlxG?.sound?.music?.fadeIn(1, FlxG?.music?.sound?.volume ?? prev_volume, prev_volume);
}

function postUpdate(elapsed:Float) {
    if (FlxG.autoPause) return;
    if (FlxG?.sound?.music?.volume > noFocusVolume && lostFocus) FlxG?.sound?.music?.volume -= 0.5 * elapsed;
}