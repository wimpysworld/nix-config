---
name: love-keyboard
description: Provides an interface to the user's keyboard. Use this skill when working with keyboard operations, key events, text input, or any keyboard-related operations in LÖVE games.
license: MIT
metadata:
  author: Ron Dekker <rondekker.nl>
---

## When to use this skill
Provides an interface to the user's keyboard. Use this skill when working with keyboard operations, key events, text input, or any keyboard-related operations in LÖVE games.

## Common use cases
- Handling keyboard input and key presses
- Managing text input and keyboard events
- Implementing keyboard-based game controls
- Working with keyboard modifiers and special keys
- Supporting international keyboard layouts

## Functions

- `love.keyboard.getKeyFromScancode(scancode: Scancode) -> key: KeyConstant`: Gets the key corresponding to the given hardware scancode. Unlike key constants, Scancodes are keyboard layout-independent. For example the scancode 'w' will be generated if the key in the same place as the 'w' key on an American keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are. Scancodes are useful for creating default controls that have the same physical locations on on all systems.
- `love.keyboard.getScancodeFromKey(key: KeyConstant) -> scancode: Scancode`: Gets the hardware scancode corresponding to the given key. Unlike key constants, Scancodes are keyboard layout-independent. For example the scancode 'w' will be generated if the key in the same place as the 'w' key on an American keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are. Scancodes are useful for creating default controls that have the same physical locations on on all systems.
- `love.keyboard.hasKeyRepeat() -> enabled: boolean`: Gets whether key repeat is enabled.
- `love.keyboard.hasScreenKeyboard() -> supported: boolean`: Gets whether screen keyboard is supported.
- `love.keyboard.hasTextInput() -> enabled: boolean`: Gets whether text input events are enabled.
- `love.keyboard.isDown` - Checks whether a certain key is down. Not to be confused with love.keypressed or love.keyreleased.
  - `love.keyboard.isDown(key: KeyConstant) -> down: boolean`: No description
  - `love.keyboard.isDown(key: KeyConstant, ...: KeyConstant) -> anyDown: boolean`: No description
- `love.keyboard.isScancodeDown(scancode: Scancode, ...: Scancode) -> down: boolean`: Checks whether the specified Scancodes are pressed. Not to be confused with love.keypressed or love.keyreleased. Unlike regular KeyConstants, Scancodes are keyboard layout-independent. The scancode 'w' is used if the key in the same place as the 'w' key on an American keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are.
- `love.keyboard.setKeyRepeat(enable: boolean)`: Enables or disables key repeat for love.keypressed. It is disabled by default.
- `love.keyboard.setTextInput` - Enables or disables text input events. It is enabled by default on Windows, Mac, and Linux, and disabled by default on iOS and Android. On touch devices, this shows the system's native on-screen keyboard when it's enabled.
  - `love.keyboard.setTextInput(enable: boolean)`: No description
  - `love.keyboard.setTextInput(enable: boolean, x: number, y: number, w: number, h: number)`: On iOS and Android this variant tells the OS that the specified rectangle is where text will show up in the game, which prevents the system on-screen keyboard from covering the text.

## Enums

- `KeyConstant`: All the keys you can press. Note that some keys may not be available on your keyboard or system.
  - `a`: The A key
  - `b`: The B key
  - `c`: The C key
  - `d`: The D key
  - `e`: The E key
  - `f`: The F key
  - `g`: The G key
  - `h`: The H key
  - `i`: The I key
  - `j`: The J key
  - `k`: The K key
  - `l`: The L key
  - `m`: The M key
  - `n`: The N key
  - `o`: The O key
  - `p`: The P key
  - `q`: The Q key
  - `r`: The R key
  - `s`: The S key
  - `t`: The T key
  - `u`: The U key
  - `v`: The V key
  - `w`: The W key
  - `x`: The X key
  - `y`: The Y key
  - `z`: The Z key
  - `0`: The zero key
  - `1`: The one key
  - `2`: The two key
  - `3`: The three key
  - `4`: The four key
  - `5`: The five key
  - `6`: The six key
  - `7`: The seven key
  - `8`: The eight key
  - `9`: The nine key
  - `space`: Space key
  - `!`: Exclamation mark key
  - `"`: Double quote key
  - `#`: Hash key
  - `$`: Dollar key
  - `&`: Ampersand key
  - `'`: Single quote key
  - `(`: Left parenthesis key
  - `)`: Right parenthesis key
  - `*`: Asterisk key
  - `+`: Plus key
  - `,`: Comma key
  - `-`: Hyphen-minus key
  - `.`: Full stop key
  - `/`: Slash key
  - `:`: Colon key
  - `;`: Semicolon key
  - `<`: Less-than key
  - `=`: Equal key
  - `>`: Greater-than key
  - `?`: Question mark key
  - `@`: At sign key
  - `[`: Left square bracket key
  - `\`: Backslash key
  - `]`: Right square bracket key
  - `^`: Caret key
  - `_`: Underscore key
  - ```: Grave accent key
  - `kp0`: The numpad zero key
  - `kp1`: The numpad one key
  - `kp2`: The numpad two key
  - `kp3`: The numpad three key
  - `kp4`: The numpad four key
  - `kp5`: The numpad five key
  - `kp6`: The numpad six key
  - `kp7`: The numpad seven key
  - `kp8`: The numpad eight key
  - `kp9`: The numpad nine key
  - `kp.`: The numpad decimal point key
  - `kp/`: The numpad division key
  - `kp*`: The numpad multiplication key
  - `kp-`: The numpad substraction key
  - `kp+`: The numpad addition key
  - `kpenter`: The numpad enter key
  - `kp=`: The numpad equals key
  - `up`: Up cursor key
  - `down`: Down cursor key
  - `right`: Right cursor key
  - `left`: Left cursor key
  - `home`: Home key
  - `end`: End key
  - `pageup`: Page up key
  - `pagedown`: Page down key
  - `insert`: Insert key
  - `backspace`: Backspace key
  - `tab`: Tab key
  - `clear`: Clear key
  - `return`: Return key
  - `delete`: Delete key
  - `f1`: The 1st function key
  - `f2`: The 2nd function key
  - `f3`: The 3rd function key
  - `f4`: The 4th function key
  - `f5`: The 5th function key
  - `f6`: The 6th function key
  - `f7`: The 7th function key
  - `f8`: The 8th function key
  - `f9`: The 9th function key
  - `f10`: The 10th function key
  - `f11`: The 11th function key
  - `f12`: The 12th function key
  - `f13`: The 13th function key
  - `f14`: The 14th function key
  - `f15`: The 15th function key
  - `numlock`: Num-lock key
  - `capslock`: Caps-lock key
  - `scrollock`: Scroll-lock key
  - `rshift`: Right shift key
  - `lshift`: Left shift key
  - `rctrl`: Right control key
  - `lctrl`: Left control key
  - `ralt`: Right alt key
  - `lalt`: Left alt key
  - `rmeta`: Right meta key
  - `lmeta`: Left meta key
  - `lsuper`: Left super key
  - `rsuper`: Right super key
  - `mode`: Mode key
  - `compose`: Compose key
  - `pause`: Pause key
  - `escape`: Escape key
  - `help`: Help key
  - `print`: Print key
  - `sysreq`: System request key
  - `break`: Break key
  - `menu`: Menu key
  - `power`: Power key
  - `euro`: Euro (&euro;) key
  - `undo`: Undo key
  - `www`: WWW key
  - `mail`: Mail key
  - `calculator`: Calculator key
  - `appsearch`: Application search key
  - `apphome`: Application home key
  - `appback`: Application back key
  - `appforward`: Application forward key
  - `apprefresh`: Application refresh key
  - `appbookmarks`: Application bookmarks key

- `Scancode`: Keyboard scancodes. Scancodes are keyboard layout-independent, so the scancode "w" will be generated if the key in the same place as the "w" key on an American QWERTY keyboard is pressed, no matter what the key is labelled or what the user's operating system settings are. Using scancodes, rather than keycodes, is useful because keyboards with layouts differing from the US/UK layout(s) might have keys that generate 'unknown' keycodes, but the scancodes will still be detected. This however would necessitate having a list for each keyboard layout one would choose to support. One could use textinput or textedited instead, but those only give back the end result of keys used, i.e. you can't get modifiers on their own from it, only the final symbols that were generated.
  - `a`: The 'A' key on an American layout.
  - `b`: The 'B' key on an American layout.
  - `c`: The 'C' key on an American layout.
  - `d`: The 'D' key on an American layout.
  - `e`: The 'E' key on an American layout.
  - `f`: The 'F' key on an American layout.
  - `g`: The 'G' key on an American layout.
  - `h`: The 'H' key on an American layout.
  - `i`: The 'I' key on an American layout.
  - `j`: The 'J' key on an American layout.
  - `k`: The 'K' key on an American layout.
  - `l`: The 'L' key on an American layout.
  - `m`: The 'M' key on an American layout.
  - `n`: The 'N' key on an American layout.
  - `o`: The 'O' key on an American layout.
  - `p`: The 'P' key on an American layout.
  - `q`: The 'Q' key on an American layout.
  - `r`: The 'R' key on an American layout.
  - `s`: The 'S' key on an American layout.
  - `t`: The 'T' key on an American layout.
  - `u`: The 'U' key on an American layout.
  - `v`: The 'V' key on an American layout.
  - `w`: The 'W' key on an American layout.
  - `x`: The 'X' key on an American layout.
  - `y`: The 'Y' key on an American layout.
  - `z`: The 'Z' key on an American layout.
  - `1`: The '1' key on an American layout.
  - `2`: The '2' key on an American layout.
  - `3`: The '3' key on an American layout.
  - `4`: The '4' key on an American layout.
  - `5`: The '5' key on an American layout.
  - `6`: The '6' key on an American layout.
  - `7`: The '7' key on an American layout.
  - `8`: The '8' key on an American layout.
  - `9`: The '9' key on an American layout.
  - `0`: The '0' key on an American layout.
  - `return`: The 'return' / 'enter' key on an American layout.
  - `escape`: The 'escape' key on an American layout.
  - `backspace`: The 'backspace' key on an American layout.
  - `tab`: The 'tab' key on an American layout.
  - `space`: The spacebar on an American layout.
  - `-`: The minus key on an American layout.
  - `=`: The equals key on an American layout.
  - `[`: The left-bracket key on an American layout.
  - `]`: The right-bracket key on an American layout.
  - `\`: The backslash key on an American layout.
  - `nonus#`: The non-U.S. hash scancode.
  - `;`: The semicolon key on an American layout.
  - `'`: The apostrophe key on an American layout.
  - ```: The back-tick / grave key on an American layout.
  - `,`: The comma key on an American layout.
  - `.`: The period key on an American layout.
  - `/`: The forward-slash key on an American layout.
  - `capslock`: The capslock key on an American layout.
  - `f1`: The F1 key on an American layout.
  - `f2`: The F2 key on an American layout.
  - `f3`: The F3 key on an American layout.
  - `f4`: The F4 key on an American layout.
  - `f5`: The F5 key on an American layout.
  - `f6`: The F6 key on an American layout.
  - `f7`: The F7 key on an American layout.
  - `f8`: The F8 key on an American layout.
  - `f9`: The F9 key on an American layout.
  - `f10`: The F10 key on an American layout.
  - `f11`: The F11 key on an American layout.
  - `f12`: The F12 key on an American layout.
  - `f13`: The F13 key on an American layout.
  - `f14`: The F14 key on an American layout.
  - `f15`: The F15 key on an American layout.
  - `f16`: The F16 key on an American layout.
  - `f17`: The F17 key on an American layout.
  - `f18`: The F18 key on an American layout.
  - `f19`: The F19 key on an American layout.
  - `f20`: The F20 key on an American layout.
  - `f21`: The F21 key on an American layout.
  - `f22`: The F22 key on an American layout.
  - `f23`: The F23 key on an American layout.
  - `f24`: The F24 key on an American layout.
  - `lctrl`: The left control key on an American layout.
  - `lshift`: The left shift key on an American layout.
  - `lalt`: The left alt / option key on an American layout.
  - `lgui`: The left GUI (command / windows / super) key on an American layout.
  - `rctrl`: The right control key on an American layout.
  - `rshift`: The right shift key on an American layout.
  - `ralt`: The right alt / option key on an American layout.
  - `rgui`: The right GUI (command / windows / super) key on an American layout.
  - `printscreen`: The printscreen key on an American layout.
  - `scrolllock`: The scroll-lock key on an American layout.
  - `pause`: The pause key on an American layout.
  - `insert`: The insert key on an American layout.
  - `home`: The home key on an American layout.
  - `numlock`: The numlock / clear key on an American layout.
  - `pageup`: The page-up key on an American layout.
  - `delete`: The forward-delete key on an American layout.
  - `end`: The end key on an American layout.
  - `pagedown`: The page-down key on an American layout.
  - `right`: The right-arrow key on an American layout.
  - `left`: The left-arrow key on an American layout.
  - `down`: The down-arrow key on an American layout.
  - `up`: The up-arrow key on an American layout.
  - `nonusbackslash`: The non-U.S. backslash scancode.
  - `application`: The application key on an American layout. Windows contextual menu, compose key.
  - `execute`: The 'execute' key on an American layout.
  - `help`: The 'help' key on an American layout.
  - `menu`: The 'menu' key on an American layout.
  - `select`: The 'select' key on an American layout.
  - `stop`: The 'stop' key on an American layout.
  - `again`: The 'again' key on an American layout.
  - `undo`: The 'undo' key on an American layout.
  - `cut`: The 'cut' key on an American layout.
  - `copy`: The 'copy' key on an American layout.
  - `paste`: The 'paste' key on an American layout.
  - `find`: The 'find' key on an American layout.
  - `kp/`: The keypad forward-slash key on an American layout.
  - `kp*`: The keypad '*' key on an American layout.
  - `kp-`: The keypad minus key on an American layout.
  - `kp+`: The keypad plus key on an American layout.
  - `kp=`: The keypad equals key on an American layout.
  - `kpenter`: The keypad enter key on an American layout.
  - `kp1`: The keypad '1' key on an American layout.
  - `kp2`: The keypad '2' key on an American layout.
  - `kp3`: The keypad '3' key on an American layout.
  - `kp4`: The keypad '4' key on an American layout.
  - `kp5`: The keypad '5' key on an American layout.
  - `kp6`: The keypad '6' key on an American layout.
  - `kp7`: The keypad '7' key on an American layout.
  - `kp8`: The keypad '8' key on an American layout.
  - `kp9`: The keypad '9' key on an American layout.
  - `kp0`: The keypad '0' key on an American layout.
  - `kp.`: The keypad period key on an American layout.
  - `international1`: The 1st international key on an American layout. Used on Asian keyboards.
  - `international2`: The 2nd international key on an American layout.
  - `international3`: The 3rd international  key on an American layout. Yen.
  - `international4`: The 4th international key on an American layout.
  - `international5`: The 5th international key on an American layout.
  - `international6`: The 6th international key on an American layout.
  - `international7`: The 7th international key on an American layout.
  - `international8`: The 8th international key on an American layout.
  - `international9`: The 9th international key on an American layout.
  - `lang1`: Hangul/English toggle scancode.
  - `lang2`: Hanja conversion scancode.
  - `lang3`: Katakana scancode.
  - `lang4`: Hiragana scancode.
  - `lang5`: Zenkaku/Hankaku scancode.
  - `mute`: The mute key on an American layout.
  - `volumeup`: The volume up key on an American layout.
  - `volumedown`: The volume down key on an American layout.
  - `audionext`: The audio next track key on an American layout.
  - `audioprev`: The audio previous track key on an American layout.
  - `audiostop`: The audio stop key on an American layout.
  - `audioplay`: The audio play key on an American layout.
  - `audiomute`: The audio mute key on an American layout.
  - `mediaselect`: The media select key on an American layout.
  - `www`: The 'WWW' key on an American layout.
  - `mail`: The Mail key on an American layout.
  - `calculator`: The calculator key on an American layout.
  - `computer`: The 'computer' key on an American layout.
  - `acsearch`: The AC Search key on an American layout.
  - `achome`: The AC Home key on an American layout.
  - `acback`: The AC Back key on an American layout.
  - `acforward`: The AC Forward key on an American layout.
  - `acstop`: Th AC Stop key on an American layout.
  - `acrefresh`: The AC Refresh key on an American layout.
  - `acbookmarks`: The AC Bookmarks key on an American layout.
  - `power`: The system power scancode.
  - `brightnessdown`: The brightness-down scancode.
  - `brightnessup`: The brightness-up scancode.
  - `displayswitch`: The display switch scancode.
  - `kbdillumtoggle`: The keyboard illumination toggle scancode.
  - `kbdillumdown`: The keyboard illumination down scancode.
  - `kbdillumup`: The keyboard illumination up scancode.
  - `eject`: The eject scancode.
  - `sleep`: The system sleep scancode.
  - `alterase`: The alt-erase key on an American layout.
  - `sysreq`: The sysreq key on an American layout.
  - `cancel`: The 'cancel' key on an American layout.
  - `clear`: The 'clear' key on an American layout.
  - `prior`: The 'prior' key on an American layout.
  - `return2`: The 'return2' key on an American layout.
  - `separator`: The 'separator' key on an American layout.
  - `out`: The 'out' key on an American layout.
  - `oper`: The 'oper' key on an American layout.
  - `clearagain`: The 'clearagain' key on an American layout.
  - `crsel`: The 'crsel' key on an American layout.
  - `exsel`: The 'exsel' key on an American layout.
  - `kp00`: The keypad 00 key on an American layout.
  - `kp000`: The keypad 000 key on an American layout.
  - `thsousandsseparator`: The thousands-separator key on an American layout.
  - `decimalseparator`: The decimal separator key on an American layout.
  - `currencyunit`: The currency unit key on an American layout.
  - `currencysubunit`: The currency sub-unit key on an American layout.
  - `app1`: The 'app1' scancode.
  - `app2`: The 'app2' scancode.
  - `unknown`: An unknown key.

## Examples

### Handling key presses
```lua
function love.keypressed(key, scancode, isrepeat)
  if key == "escape" then
    love.event.quit()
  elseif key == "space" then
    player.jump()
  elseif key == "w" or key == "up" then
    player.moveForward()
  end
end
```

### Text input
```lua
function love.textinput(text)
  -- Handle text input for chat or UI
  if chatting then
    chatMessage = chatMessage .. text
  end
end

function love.keypressed(key)
  if key == "backspace" and chatting then
    -- Remove last character
    chatMessage = chatMessage:sub(1, -2)
  elseif key == "return" and chatting then
    -- Send chat message
    sendChatMessage(chatMessage)
    chatMessage = ""
  end
end
```

## Best practices
- Handle both key names and scancodes appropriately
- Support keyboard remapping for accessibility
- Consider international keyboard layouts
- Test keyboard input on different platforms
- Be mindful of keyboard repeat behavior

## Platform compatibility
- **Desktop (Windows, macOS, Linux)**: Full keyboard support
- **Mobile (iOS, Android)**: Limited to on-screen keyboards
- **Web**: Full keyboard support in browser environment
