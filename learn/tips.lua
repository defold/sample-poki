-- Tips for making games with Defold for Poki.
-- Each context is a list of cards.
-- Defold Foundation 2026
local M = {}

M.TIPS = {
	first_contact = {
		{
			title = "About this guide",
			body = "Welcome to the Defold guide for Poki webgames! These tips are designed to help you build better games for Poki and have everything necessary.\n\nWhen you play the game, finish the level, fail, win, or open any pop-up or new screen - click the Poki logo in the right bottom corner or [P] key to display these tips in the given context.\n\nRead them all - use arrows keys to change the step. `Close it` button closes the pop-up.",
		},
		{
			title = "First impression",
			body = "You have just a few seconds to convice players to stay longer.\n\nGet players straight into the gameplay, so load game fast and skip any logo splash screens or menus in the very beginning to get straight to the interesting part of the gameplay.\n\nIt should be a good vertical slice of the game - easy to get, engaging, encourages to play more.",
		},
		{
			title = "Initial loading",
			body = "Initial loading time should be as short as possible.\n\nThe loading progress bar is still there though and is part of the pitch. You can customize your loading page in Defold using a custom HTML5 template with game's logo, some image or tips.\n\nYou can measure the real HTML5 transfer size and time with cache disabled and using browser tools to check on different network types.",
		},
		{
			title = "Build size",
			body = "Keep the initial download as small as possible, but do not rely on a fixed size target: the effective transfer size and loading time depend on the build, compression, device, cache, and connection.\n\nCompress images, textures, models, and audio files, and keep music short and loopable. Remove unused extensions and assets, or load optional content later with Live Update.\n\nMeasure the real HTML5 transfer size and loading time with the cache disabled, then simplify the first level or area if the initial download is still too large.",
		},
		{
			title = "Live Update",
			body = "Anything an atlas, collection, or factory references enters the initial download, even if it is hidden or not used in the beginning.\n\nAssets that are not needed in the very beginning (music tracks, sounds, models or textures of objects not appearing in the first level) and fonts not used by the given player should be separated and stripped out of the game and loaded later on using Live Update when needed.",
		},
		{
			title = "Failed connection",
			body = "Though web games require internet connection to even load, the connection might be lost later and there might occur some problems when loading deferred content.\n\nA failed fetch should not block the game and it should be handled, have a fallback to something default and display an information to user and eventually an option to check connection and retry.",
		},
		{
			title = "First contact",
			body = "Game should rather stay in a `pause` mode waiting for the first user interaction.\n\nUtilise this space to explain the basic controls and how to play the game, preferably with images.\n\nWhen input is detected - unpause and start the game, send `gameplay_start` Poki event and eventually start the game's audio.",
		},
		{
			title = "How to play",
			body = "Teaching how to play is crucial. Some games require few or no words to explain the mechanics and controls.\n\nShow as much as possible with images, animations or with interactive tutorial in the game.\n\nAvoid much text, but if it's needed, it's good to take care about localization.",
		},
		{
			title = "Common controls",
			body = "Players search for common control tropes in games, so research how similar games are controlled first and try to use the same or similar layout.\n\nUse recognizable icons for controls and update them for the active input device. Show keyboard inputs, when keyboard or mouse is used, touch overlays for mobile devices, and gamepad icons only if it's detected and used."
		},
		{
			title = "Sounds good",
			body = "Some games start audio from the beginning, but it's good to remember not to start out loud.\n\nNice sounds gain fade animations help to make the transitions smooth.\n\nIt's not recommended to autoplay music during loading, but when game starts you can convince players to your game with music as well.",
		},
	},
	gameplay = {
		{
			title = "Many inputs",
			body = "A web game can be played with a keyboard, mouse, touch screen, or gamepad.\n\nEvery supported device should allow the same actions, even if the gesture or layout is different.\n\nFor example, player using keyboard may steer with A/D or arrows, with a mouse/touch - may drag or use virutal on-screen joystick, and with a gamepad - may use the stick. The result in the game should still be the same.",
		},
		{
			title = "Inputs hints",
			body = "Players understand controls faster when the game shows the input they are using right now.\n\nDisplay keyboard keys icons when keyboard or mouse is used on desktop web browser, show touch guidance icons or virtual joy-stick overlay for touch input, and gamepad glyphs only after a gamepad is really used.",
		},
		{
			title = "Control menus",
			body = "Menus need keyboard and gamepad controls too. These take extra work: players need a way to move between buttons without a pointer.\n\nIt's good to support using keys or a gamepad to move a visible UI selection, change a value, confirm an action, or close a popup and go back without reaching for the mouse.\n\nKeep pointer and touch controls working at the same time."
		},
		{
			title = "Menu with keys",
			body = "Use a familiar control pattern if possible: arrows, WASD, or a stick to move and change `focus`/`highlight` in the UI lists or grids, and a main action key/button to confirm selection, toggle or change value.\n\nIt's good to also place key and gamepad icons over or near the button, but do not cover the text inside the label. Hide them when not needed.",
		},
		{
			title = "Touch control",
			body = "Test menus and popups on a small phone. Use the available width, keep text readable, and leave room for the controls.\n\nMake touch targets large and clearly spaced so a finger cannot easily hit two actions. Keep them away from browser edges and other overlays. Give Close a clear label and a distinct color, separated from navigation buttons, to avoid accidental dismissal.\n\nUse drags, swipes, or on-screen controls only when they match the game.",
		},
		{
			title = "Virtual joystick",
			body = "Virtual joystick overlay is an easy trick for more complex controls to directly port them from gamepad or keyboard origin.\n\nA touch overlay should help the player understand the action, but should not cover the playfield. Always try the real interaction on a phone-sized screen; a mouse simulation does not reveal every problem.\n\nOn desktop use [U] key here to toggle virtual joystick",
		},
		{
			title = "Resolutions",
			body = "Games are played on different devices. Players can resize the browser window during a game.\n\nTest your game on different resolutions and aspect ratios and fix any issues regarding resizing. Check that gameplay and UI elements fit within the window and that players can read the text and distinguish the icons."
		},
		{
			title = "Orientations",
			body = "A device orientation may be changed. Use Defold `Landscape` and `Portrait` layouts instead of stretching the screen.\n\nKeep the game rules the same unless your design truly needs a different mode for vertical or horizontal layout. Usually only the camera framing and UI should change.\n\nCheck that players can read the text, see meter values, and identify buttons in both orientations.",
		},
		{
			title = "Poki Pill",
			body = "The Poki Pill is part of the page where your game runs. On mobile devices in portrait mode, it is placed in the top-left corner by default. Treat its area as a safe zone where no critical gameplay or UI should be placed.\n\nLeave enough space around the Poki Pill so players can use it without accidentally pressing a game control. You can change the Poki Pill position using the SDK when your layout requires it.",
		},
		{
			title = "Camera adjustment",
			body = "Updating a GUI layout does not automatically give the camera the correct aspect ratio.\n\nWhen the browser changes size, update the camera independently so the world is not stretched, cropped unexpectedly, or made easier or harder to play.\n\nCheck the actual game view in both orientations, especially where hazards or targets appear near the edge of the screen.",
		},
		{
			title = "Play time",
			body = "Report Poki lifecycle events when play actually starts and stops so play time is measured accurately. One `gameplay_start` when gameplay begins and one `gameplay_stop` when it ends or is interrupted. Never send two starts or two stops in a row.\n\nThe shop, pause screen, tutorial, or result screen are not gameplay sessions. Stop before showing them, then wait for a new input during the new game before starting again.",
		},
		{
			title = "Pausing game",
			body = "Pause the game before a pause popup, focus loss, an ad break, or a result screen. If the player cannot control the game, stop the simulation unless automatic progress is part of the design, as in idle games.\n\nAn ad is especially important: stop gameplay before requesting it and do not send lifecycle or measurement events during the ad.",
		},
		{
			title = "Web build",
			body = "Build HTML5, test it in a browser, and include an older or weaker device in the tests.\n\nAim for stable frame pacing, a small draw-call count, and no growing memory use during a gameplay session.\n\nMeasure before optimizing. Then remove or simplify the part that costs the most if needed.",
		},
	},
	pause = {
		{
			title = "Pause game",
			body = "When the player opens the pause menu, the gameplay should actually stop.\n\nSend `gameplay_stop` event before showing the pause UI and freeze the game world. If the game is dynamic, do not let it keep moving.\n\nAfter closing the pause screen, the player should always return to exactly the same situation they paused.",
		},
		{
			title = "Focus loss",
			body = "When the game window loses the focus (player switches to a different tab or window) the game should open the pause menu, and the gameplay should actually stop.",
		},
		{
			title = "Resume game",
			body = "Choose the resume behavior to fit the genre. Real-time or action games should usually stay paused until the player makes a new intentional move, click, tap, or button press, so they do not return directly into danger.\n\nIdle, turn-based, or otherwise non-real-time games may resume automatically when that is part of the design, but the transition should remain clear and predictable.\n\nSend one `gameplay_start` event when gameplay actually starts, not merely when the pause popup closes.",
		},
		{
			title = "Pause UI",
			body = "The pause popup UI is a good place for common game settings such as sound, language, or maybe some credits, or a short help section. It is easier for the player than searching for a separate settings screen.\n\nAdd the resume/closing action button/key.\n\nUse the same pause UI in different parts of the game when possible.",
		},
		{
			title = "Sound settings",
			body = "Players expect the mute/unmute choice to stay saved. Store it in the player profile and restore it when the game is opened again.\n\nDo not confuse mute with temporary audio changes. Ads, focus loss, or browser restrictions may lower or stop the sound for a moment, but they should not change the player's chosen setting.\n\nWhen the ad ends or the browser regains focus, keep the game muted if the player selected mute.",
		},
		{
			title = "Language settings",
			body = "Language selection can live in the pause screen too. Let players change it with mouse, touch, keyboard, or gamepad, and save the selected language in their profile.\n\nIf some fonts or language files are downloaded later, do not let that block the first level or basic UI. Keep a working fallback language and show a clear result if the extra content cannot be loaded.\n\nA language setting should make the game more accessible, never prevent the player from continuing.",
		},
		{
			title = "Credits and extra popups",
			body = "Credits, legal information, or help can open as another popup from the pause screen. When the player closes it, return them to pause - not directly to the game.\n\nThe pause state should stay active under any extra popup. The player still needs to select Resume and then make a new gameplay input before the mission continues.\n\nThe player can then close a popup without accidentally resuming gameplay behind it.",
		},
		{
			title = "Clear button labels",
			body = "A button label should describe the action: Resume, Close, Sound On, or Change Language. Do not replace the action name with a keyboard key or gamepad button.\n\nShow key and gamepad glyphs as separate small hints near the button. Hide them on touch devices when the touch UI already makes the action clear.\n\nPlayers can then identify each action from its label, regardless of their input device or language.",
		},
	},
	focus = {
		{
			title = "Lost focus",
			body = "A browser game can lose focus when the player changes tab, opens another window, clicks on a notification, or minimizes the browser. Treat this situation like a regular pause.\n\nStop gameplay with one `gameplay_stop` event, freeze the game world, and lower or stop the audio. The game should not keep moving, spend resources, score points, etc.",
		},
		{
			title = "Returning focus",
			body = "When the browser window becomes active again, account for the genre and any progress made in the background. Real-time games should usually wait for player input before resuming. Idle or turn-based games may resume automatically if that is intentional and clearly communicated.\n\nOnly send `gameplay_start` when gameplay actually resumes, and restore audio without overriding the player's mute choice.\n\nThe return should be predictable and should not put the player in unexpected danger.",
		},
	},
	resume = {
		{
			title = "Resuming from popups",
			body = "A button that closes a popup should not accidentally count as a new gameplay action.\n\nFor real-time games, keep the game paused after the popup closes and wait for the next intentional input before restarting gameplay. Idle or turn-based games may resume immediately when that is part of the design.\n\nSend one `gameplay_start` event when gameplay actually resumes and make the transition clear to the player.",
		},
	},
	mothership = {
		{
			title = "Shop UI",
			body = "The shop, or upgrade screens in this game are a place to make choices between missions. If it is not part of the core game loop - it should not be counted as a gameplay session.\n\nBrowsing ships, upgrades, skins, or credits should not trigger Poki `gameplay_start` or `gameplay_stop` events. Start gameplay only when they enter a game and make the first input.",
		},
		{
			title = "Continue to game",
			body = "The main Continue/Retry/Back to game action should be the clearest action in the screens outside core loop. It must always lead the player back to the game.\n\nIt should be a default first selection, especially when using keyboard/gamepad, so that player can return easily to the game.\n\nThe player should never wonder whether they are allowed to play the next level and how to do so.",
		},
		{
			title = "Progression",
			body = "Progression systems enrich the game. There is a lot of design choices, but generally one currency and a few clear purchases are easier to understand for players at first.\n\nLet players earn credits/coins by playing and use them for useful upgrades or ships. It is not recommended to hide many meaningful progression upgrades behind ads, but on the other hand rewarded ads for benefits in the game are generally acceptable.",
		},
		{
			title = "Failures",
			body = "A failed mission does not need to feel like wasted time. A small consolation reward can help the player e.g. afford an upgrade and try a different approach.\n\nKeep the reward clearly smaller than a win so completing the mission still matters. The player should learn from failure, not feel forced to grind it. This is especially useful early in the game, when a new player is still learning the controls.",
		},
		{
			title = "Rewarded Ads",
			body = "Rewarded ads should be available through intentional user interaction - e.g. choosing an option that visibly leads to an ad. Explain clearly what the player will receive before they choose it.\n\nA cosmetic skin can be offered through an explicit Rewarded Ad action, especially because it does not affect the player's chance to win.",
		},
		{
			title = "Ads buttons",
			body = "Rewarded Ads buttons must not use green, which is reserved for general confirmation or success actions. Give them a distinct non-green color and include a prominent clapperboard/video icon on every rewarded button.\n\nUse the same visual convention in result screens, shop offers, and confirmation popups so players can recognize a rewarded action immediately.",
		},
		{
			title = "Ad confirmation",
			body = "Use a separate action (key/gamepad button) to open the Ad. Space, Enter, or other main Continue action must never start a rewarded ad by accident.\n\nIt's good to add a confirmation popup - if the player chooses not to watch it now, leave Continue action available and let them play normally.",
		},
		{
			title = "Commercial break",
			body = "Offer a commercial break at a natural return to play, such as Continue or Retry between missions or Resume from a pause. Keep gameplay stopped until the break finishes; Poki decides whether an ad is shown.\n\nThis sample starts offering commercial breaks from mission 5, so earlier missions have no commercial breaks. If no ad is shown, continue normally.",
		},
		{
			title = "Saving",
			body = "Save progress such as unlocked missions/levels, currency, player character upgrades, settings, and tutorial state. Keep the saved data small, generic, extendable and also easy to recover.\n\nBrowser storage can fail in browser, e.g. when space is limited, or when the player has disabled it. Keep an in-memory fallback so at least the current session remains playable.",
		},
		{
			title = "Third party",
			body = "Poki does not allow third-party outgoing requests, logins, ads or outbound links. If you need them, request it specially with Poki.\n\nUse only the platform services your game genuinely needs, e.g. no need to check whether an ad blocker exists.\n\nA simple, self-contained game is more reliable for players and for platform review.",
		},
		{
			title = "Poki Inspector",
			body = "Editor builds are not proof that a web game behaves correctly on Poki. Build the HTML5/Poki version and test it in Poki Inspector.\n\nBeside game simply working on web - read the Event Log. Check loading, and lifecycle events.\n\nPoki inspector allows to check all events, ads, and correctness of gameplay time measurements.",
		},
		{
			title = "Final checklist",
			body = "Before release, before applying the game for Poki review, check the complete game and all the features once again.\n\nConfirm that loading is short, rewarded ads are handled correctly, and the game works in all resolutions, and also in portrait and landscape mode, with every supported input method.",
		},
	},
	ads = {
		{
			title = "Rewarded ads",
			body = "A rewarded ad should always be optional.\n\nExplain the reward before the player chooses it, for example a cosmetic skin, revive, or ammo refill. Use a different visual treatment for rewarded actions so they are never confused with Continue.\n\nThe player should be able to avoid the reward ad and still continue playing.",
		},
		{
			title = "Ad confirmation",
			body = "It is recommended to show a clear confirmation before requesting the rewarded ad, perhaps even a confirmation popup.\n\nKeep Space, Enter, and other default Continue actions, and use a separate button to open the rewarded route.\n\nThis prevents an ad from becoming the accidental default choice.",
		},
		{
			title = "Failure",
			body = "Grant the reward only after the ad provider reports `events.SUCCESS`. Cancel, skip, error, or an unavailable ad should not grant the reward.\n\nStore or track the transaction so the same successful callback cannot grant the reward twice.\n\nThis protects both the player economy and the trust between the game and the platform.",
		},
		{
			title = "Asynchronous Ads",
			body = "Ads are asynchronous. A player can tap quickly, callbacks can arrive later, so two requests must never overlap.\n\nUse an `ad_busy` state to block another commercial or rewarded request until the current one finishes. Pass the required params table to each rewarded call and clear the busy state in every outcome.",
		},
		{
			title = "Pause on ad",
			body = "Stop gameplay before an ad starts and keep the world paused for the whole break. Stop game audio also.\n\nDo not send `gameplay_start`, `gameplay_stop`, or level measurement events during the ad. Wait for the ad callback, restore the game state, and then return to game.",
		},
		{
			title = "No chained ads",
			body = "After a rewarded ad, return the player to the game or the popup/screen they were using. Do not immediately request a commercial break after it to avoid ad after ad.\n\nA commercial should be a bit later, as a natural break between missions.\n\nOne ad at a time is much less disruptive.",
		},
		{
			title = "Third party",
			body = "Use Poki as the game's ad platform. Do not add another ad network, custom ad-block detection, or other third party services.\n\nIf an ad cannot be shown, treat it as an unavailable optional feature and keep the game playable.\n\nThese are Poki integration requirements.",
		},
	},
	result = {
		{
			title = "Result",
			body = "A level or mission or other separated part of the game should have a final result. The result should be exactly - one completed/success and one fail screen/popup.\n\nKeep the success or fail decision in one place in the game flow.\n\nUse visual effects, like particles or animations for the success, to reward the player.",
		},
		{
			title = "Pause",
			body = "When a mission is completed or failed, stop gameplay before showing the result popup. The win screen and fail screen are a moment to read feedback and choose whether to retry, or maybe proceed to upgrades, etc. It is not a playtime.\n\nPause the world behind the popup.",
		},
		{
			title = "Level tracking",
			body = "It's good to track whether players completed or failed the given level. You can then compare it with play time statistics.\n\nChoose an ID for a level to reuse it for its start and matching complete or fail result events. Avoid noisy extra events and duplicate results. A consistent name turns the event log into a useful record of a player journey.",
		},
		{
			title = "Commercial breaks",
			body = "A commercial break is an opportunity on the way back into play. Continue and Retry are good examples of natural moments to call a break ad.\n\nGameplay should be already stopped at that point. Ask Poki for the break, then continue normally whether an ad is shown or not.\n\nDo not place a commercial break on the first entry into the game.",
		},
	},
	fail = {
		{
			title = "Retry",
			body = "After a failed mission, you can present to user a feedback - why it failed (e.g. like health or ammo depleted or mission objectives failed).\n\nThe standard Retry or proceeding to shop/upgrades action should be the clearest and easiest to access next choice.",
		},
		{
			title = "Retry for an ad",
			body = "Failing is a good oportunity to propose to users watching a rewarded ad to revive/restart and keep playing.\n\nKeep the Rewarded Ad button though visually separate and never make it the default action.\n\nThe player should feel invited to try again, not pressured to watch an ad.",
		},
		{
			title = "Rewarded ad confirmation",
			body = "It is good to open a rewarded ad confirmation popup with a separate action to confirm it, or leave it.\n\nAfter cancelling, or an error, keep the offer available if the mission still allows it.\n\nHide it only after a successful ad flow and apply the rward.",
		},
		{
			title = "No rewarded vs break ad",
			body = "A failed or cancelled rewarded request means player didn't want to see the ad now. It's probably then not a good idea to show the commercial break then, but on the other hand it is a good, natural place to show it, before the level is restarted. It is though less noticeable, when there is an upgrade/shop screen between levels.",
		},
		{
			title = "Repeating failures",
			body = "A revive, health or ammo refill rewarded for watching an ad can give the player one optional chance to replay a mission, but it's good to keep that rescue limited to one or a few at most opportunities per the run, in order not to turn failures into repeated ad offers.\n\nLimit retries so players get another chance without making failure meaningless.",
		},
		{
			title = "Rewarded Ad Failure",
			body = "After cancelled, failed or explicitly skipped ad, the normal path still should lead back to continue the game. The player should never need an ad to leave the fail screen.\n\nA commercial opportunity may happen during that natural return toward the next mission, but it should never replace Continue action.\n\nEven after failure, the next action should be clear, respectful of the player's choice.",
		},
	},
}

local AD_POPUPS = {
	rewarded_confirm = true,
	rewarded_pending = true,
	skin_rewarded_confirm = true,
	skin_rewarded_pending = true,
}

---Normalize a context entry to a card list.
---@param id string|nil
---@return table|nil
function M.pages(id)
	local entry = id and M.TIPS[id]
	if type(entry) ~= "table" then
		return nil
	end
	if entry[1] ~= nil then
		return entry
	end
	if entry.title or entry.body then
		return { entry }
	end
	return nil
end

---Count the tip cards in a Learn context.
---@param id string|nil
---@return integer
function M.count(id)
	local pages = M.pages(id)
	return pages and #pages or 0
end

---Read one tip card, using the first card when no page is given.
---@param id string|nil
---@param page integer|nil
---@return table|nil
function M.card(id, page)
	local pages = M.pages(id)
	if not pages then
		return nil
	end
	local index = page or 1
	if index < 1 then
		index = 1
	elseif index > #pages then
		index = #pages
	end
	return pages[index]
end

---Wrap `page` by `delta` inside the context's card list.
---@param id string|nil
---@param page integer|nil
---@param delta integer|nil
---@return integer
function M.step(id, page, delta)
	local count = M.count(id)
	if count < 1 then
		return 1
	end
	return (((page or 1) - 1 + (delta or 0)) % count) + 1
end

---Resolve the teaching context from live app/ui state.
---@param state table
---@return string|nil
function M.context(state)
	state = state or {}
	local popup = state.popup
	if popup and AD_POPUPS[popup] then
		return "ads"
	end
	if popup == "result" then
		if state.result_status == "complete" then
			return "result"
		end
		return "fail"
	end
	if state.is_awaiting_resume then
		return "resume"
	end
	if state.pause_reason == "focus_lost" then
		return "focus"
	end
	if state.is_paused or popup == "pause" then
		return "pause"
	end
	if state.screen == "mothership" then
		return "mothership"
	end
	if state.screen == "gameplay" and state.phase == "PREPLAY" then
		return "first_contact"
	end
	if state.screen == "gameplay" then
		return "gameplay"
	end
	return nil
end

return M
