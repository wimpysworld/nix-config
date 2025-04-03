#!/usr/bin/env bash
# Slightly tweaked version of https://github.com/evanriley/fuzzel-emoji
set -euo pipefail

EMOJI="$(sed '1,/^### DATA ###$/d' $0 | fuzzel --dmenu --prompt="󰞅 " --match-mode=exact --width=48 | cut -d ' ' -f 1 | tr -d '\n')"
wtype "$EMOJI"; wl-copy "$EMOJI"
exit
### DATA ###
😀 grinning face face smile happy joy :D grin smiley
😃 grinning face with big eyes face happy joy haha :D :) smile funny mouth open smiley smiling
😄 grinning face with smiling eyes face happy joy funny haha laugh like :D :) smile eye grin mouth open pleased smiley
😁 beaming face with smiling eyes face happy smile joy kawaii eye grin grinning
😆 grinning squinting face happy joy lol satisfied haha face glad XD laugh big closed eyes grin laughing mouth open smile smiling tightly
😅 grinning face with sweat face hot happy laugh sweat smile relief cold exercise mouth open smiling
🤣 rolling on the floor laughing face rolling floor laughing lol haha rofl laugh rotfl
😂 face with tears of joy face cry tears weep happy happytears haha crying laugh laughing lol tear
🙂 slightly smiling face face smile fine happy this
🙃 upside down face face flipped silly smile sarcasm
😉 winking face face happy mischievous secret ;) smile eye flirt wink winky
😊 smiling face with smiling eyes face smile happy flushed crush embarrassed shy joy ^^ blush eye proud smiley
😇 smiling face with halo face angel heaven halo innocent fairy fantasy smile tale
🥰 smiling face with hearts face love like affection valentines infatuation crush hearts adore eyes three
😍 smiling face with heart eyes face love like affection valentines infatuation crush heart eye shaped smile
🤩 star struck face smile starry eyes grinning excited eyed wow
😘 face blowing a kiss face love like affection valentines infatuation kiss blow flirt heart kissing throwing
😗 kissing face love like face 3 valentines infatuation kiss duck kissy whistling
☺️ smiling face face blush massage happiness happy outlined pleased relaxed smile smiley white
😚 kissing face with closed eyes face love like affection valentines infatuation kiss eye kissy
😙 kissing face with smiling eyes face affection valentines infatuation kiss eye kissy smile whistle whistling
😋 face savoring food happy joy tongue smile face silly yummy nom delicious savouring goofy hungry lick licking lips smiling um yum
😛 face with tongue face prank childish playful mischievous smile tongue cheeky out stuck
😜 winking face with tongue face prank childish playful mischievous smile wink tongue crazy eye joke out silly stuck
🤪 zany face face goofy crazy excited eye eyes grinning large one small wacky wild
😝 squinting face with tongue face prank playful mischievous smile tongue closed eye eyes horrible out stuck taste tightly
🤑 money mouth face face rich dollar money eyes sign
🤗 hugging face face smile hug hands hugs open smiling
🤭 face with hand over mouth face whoops shock surprise blushing covering eyes quiet smiling
🤫 shushing face face quiet shhh closed covering finger hush lips shh shush silence
🤔 thinking face face hmmm think consider chin shade thinker throwing thumb
🤐 zipper mouth face face sealed zipper secret hush lips silence zip
🤨 face with raised eyebrow face distrust scepticism disapproval disbelief surprise suspicious colbert mild one rock skeptic
😐 neutral face indifference meh :| neutral deadpan faced mouth straight
😑 expressionless face face indifferent - - meh deadpan inexpressive mouth straight unexpressive
😶 face without mouth face blank mouthless mute no quiet silence silent
😏 smirking face face smile mean prank smug sarcasm flirting sexual smirk suggestive
😒 unamused face indifference bored straight face serious sarcasm unimpressed skeptical dubious ugh side eye dissatisfied meh unhappy
🙄 face with rolling eyes face eyeroll frustrated eye roll
😬 grimacing face face grimace teeth awkward eek mouth nervous
🤥 lying face face lie pinocchio liar long nose
😌 relieved face face relaxed phew massage happiness content pleased whew
😔 pensive face face sad depressed upset dejected sadface sorrowful
😪 sleepy face face tired rest nap bubble side sleep snot tear
🤤 drooling face face drool
😴 sleeping face face tired sleepy night zzz sleep snoring
😷 face with medical mask face sick ill disease covid cold coronavirus doctor medicine surgical
🤒 face with thermometer sick temperature thermometer cold fever covid ill
🤕 face with head bandage injured clumsy bandage hurt bandaged injury
🤢 nauseated face face vomit gross green sick throw up ill barf disgust disgusted green face
🤮 face vomiting face sick barf ill mouth open puke spew throwing up vomit
🤧 sneezing face face gesundheit sneeze sick allergy achoo
🥵 hot face face feverish heat red sweating overheated stroke
🥶 cold face face blue freezing frozen frostbite icicles ice
🥴 woozy face face dizzy intoxicated tipsy wavy drunk eyes groggy mouth uneven
😵 dizzy face spent unconscious xox dizzy cross crossed dead eyes knocked out spiral eyes
🤯 exploding head face shocked mind blown blowing explosion mad
🤠 cowboy hat face face cowgirl hat
🥳 partying face face celebration woohoo birthday hat horn party
😎 smiling face with sunglasses face cool smile summer beach sunglass best bright eye eyewear friends glasses mutual snapchat sun weather
🤓 nerd face face nerdy geek dork glasses smiling
🧐 face with monocle face stuffy wealthy rich
😕 confused face face indifference huh weird hmmm :/ meh nonplussed puzzled s
😟 worried face face concern nervous :( sad sadface
🙁 slightly frowning face face frowning disappointed sad upset frown unhappy
☹️ frowning face face sad upset frown megafrown unhappy white
😮 face with open mouth face surprise impressed wow whoa :O surprised sympathy
😯 hushed face face woo shh silence speechless stunned surprise surprised
😲 astonished face face xox surprised poisoned amazed drunk face gasp gasping shocked totally
😳 flushed face face blush shy flattered blushing dazed embarrassed eyes open shame wide
🥺 pleading face face begging mercy cry tears sad grievance eyes glossy puppy simp
😦 frowning face with open mouth face aw what frown yawning
😧 anguished face face stunned nervous pained
😨 fearful face face scared terrified nervous fear oops shocked surprised
😰 anxious face with sweat face nervous sweat blue cold concerned face mouth open rushed
😥 sad but relieved face face phew sweat nervous disappointed eyebrow whew
😢 crying face face tears sad depressed upset :'( cry tear
😭 loudly crying face sobbing face cry tears sad upset depressed bawling sob tear
😱 face screaming in fear face munch scared omg alone fearful home horror scream shocked
😖 confounded face face confused sick unwell oops :S mouth quivering scrunched
😣 persevering face face sick no upset oops eyes helpless persevere scrunched struggling
😞 disappointed face face sad upset depressed :( sadface
😓 downcast face with sweat face hot sad tired exercise cold hard work
😩 weary face face tired sleepy sad frustrated upset distraught wailing
😫 tired face sick whine upset frustrated distraught exhausted fed up
🥱 yawning face tired sleepy bored yawn
😤 face with steam from nose face gas phew proud pride triumph airing frustrated grievances look mad smug steaming won
😡 pouting face angry mad hate despise enraged grumpy pout rage red
😠 angry face mad face annoyed frustrated anger grumpy
🤬 face with symbols on mouth face swearing cursing cussing profanity expletive covering foul grawlix over serious
😈 smiling face with horns devil horns evil fairy fantasy happy imp purple red devil smile tale
👿 angry face with horns devil angry horns demon evil fairy fantasy goblin imp purple sad tale
💀 skull dead skeleton creepy death dead body danger face fairy grey halloween monster poison tale
☠️ skull and crossbones poison danger deadly scary death pirate evil body face halloween monster
💩 pile of poo hankey shitface fail turd shit comic crap dirt dog dung face monster poop smiling
🤡 clown face face
👹 ogre monster red mask halloween scary creepy devil demon japanese ogre creature face fairy fantasy oni tale
👺 goblin red evil mask monster scary creepy japanese goblin creature face fairy fantasy long nose tale tengu
👻 ghost halloween spooky scary creature disappear face fairy fantasy ghoul monster tale
👽 alien UFO paul weird outer space creature et extraterrestrial face fairy fantasy monster tale
👾 alien monster game arcade play creature extraterrestrial face fairy fantasy invader retro space tale ufo video
🤖 robot computer machine bot face monster
😺 grinning cat animal cats happy smile face mouth open smiley smiling
😸 grinning cat with smiling eyes animal cats smile eye face grin happy
😹 cat with tears of joy animal cats haha happy tears face laughing tear
😻 smiling cat with heart eyes animal love like affection cats valentines heart eye face loving cat shaped smile
😼 cat with wry smile animal cats smirk face ironic smirking
😽 kissing cat animal cats kiss closed eye eyes face
🙀 weary cat animal cats munch scared scream face fear horror oh screaming surprised
😿 crying cat animal tears weep sad cats upset cry face sad cat tear
😾 pouting cat animal cats face grumpy
🙈 see no evil monkey monkey animal nature haha blind covering eyes face forbidden gesture ignore mizaru not prohibited
🙉 hear no evil monkey animal monkey nature covering deaf ears face forbidden gesture kikazaru not prohibited
🙊 speak no evil monkey monkey animal nature omg covering face forbidden gesture hush iwazaru mouth mute not no speaking prohibited
💋 kiss mark face lips love like affection valentines heart kissing lipstick romance
💌 love letter email like affection envelope valentines heart mail note romance
💘 heart with arrow love like heart affection valentines cupid lovestruck romance
💝 heart with ribbon love valentines box chocolate chocolates gift valentine
💖 sparkling heart love like affection valentines excited sparkle sparkly stars heart
💗 growing heart like love affection valentines pink excited heartpulse multiple nervous pulse triple
💓 beating heart love like affection valentines pink heart alarm heartbeat pulsating wifi
💞 revolving hearts love like affection valentines heart two
💕 two hearts love like affection valentines heart pink small
💟 heart decoration purple-square love like
❣️ heart exclamation decoration love above an as dot heavy mark ornament punctuation red
💔 broken heart sad sorry break heart heartbreak breaking brokenhearted
❤️ red heart love like valentines black heavy
🧡 orange heart love like affection valentines
💛 yellow heart love like affection valentines bf gold snapchat
💚 green heart love like affection valentines nct
💙 blue heart love like affection valentines brand neutral
💜 purple heart love like affection valentines bts emoji
🤎 brown heart coffee
🖤 black heart evil dark wicked
🤍 white heart pure
💯 hundred points score perfect numbers century exam quiz test pass hundred 100 full keep symbol
💢 anger symbol angry mad comic pop sign vein
💥 collision bomb explode explosion blown bang boom comic impact red spark symbol
💫 dizzy star sparkle shoot magic circle comic symbol
💦 sweat droplets water drip oops comic drops plewds splashing symbol workout
💨 dashing away wind air fast shoo fart smoke puff blow comic dash gust running steam symbol vaping
🕳️ hole embarrassing
💣 bomb boom explode explosion terrorism comic
💬 speech balloon bubble words message talk chatting chat comic comment dialog
👁️‍🗨️ eye in speech bubble info am i witness
🗨️ left speech bubble words message talk chatting dialog
🗯️ right anger bubble caption speech thinking mad angry balloon zag zig
💭 thought balloon bubble cloud speech thinking dream comic
💤 zzz sleepy tired dream bedtime boring comic sign sleep sleeping symbol
👋 waving hand wave hands gesture goodbye solong farewell hello hi palm body sign
🤚 raised back of hand fingers raised backhand body
🖐️ hand with fingers splayed hand fingers palm body finger five raised
✋ raised hand fingers stop highfive palm ban body five high
🖖 vulcan salute hand fingers spock star trek between body finger middle part prosper raised ring split
👌 ok hand fingers limbs perfect ok okay body sign
🤏 pinching hand tiny small size amount body little
✌️ victory hand fingers ohyeah hand peace victory two air body quotes sign v
🤞 crossed fingers good lucky body cross finger hand hopeful index luck middle
🤟 love you gesture hand fingers gesture body i ily sign
🤘 sign of the horns hand fingers evil eye sign of horns rock on body devil finger heavy metal
🤙 call me hand hands gesture shaka body phone sign
👈 backhand index pointing left direction fingers hand left body finger point white
👉 backhand index pointing right fingers hand direction right body finger point white
👆 backhand index pointing up fingers hand direction up body finger middle point white
🖕 middle finger hand fingers rude middle flipping bird body dito extended fu medio middle finger reversed
👇 backhand index pointing down fingers hand direction down body finger point white
☝️ index pointing up hand fingers direction up body finger point secret white
👍 thumbs up thumbsup yes awesome good agree accept cool hand like +1 approve body ok sign thumb
👎 thumbs down thumbsdown no dislike hand -1 bad body bury disapprove sign thumb
✊ raised fist fingers hand grasp body clenched power pump punch
👊 oncoming fist angry violence fist hit attack hand body bro brofist bump clenched closed facepunch fisted punch sign
🤛 left facing fist hand fistbump body bump leftwards
🤜 right facing fist hand fistbump body bump rightwards right fist
👏 clapping hands hands praise applause congrats yay body clap golf hand round sign
🙌 raising hands gesture hooray yea celebration hands air arms banzai body both festivus hallelujah hand miracle person praise raised two
👐 open hands fingers butterfly hands open body hand hug jazz sign
🤲 palms up together hands gesture cupped prayer body dua facing
🤝 handshake agreement shake deal hand hands meeting shaking
🙏 folded hands please hope wish namaste highfive pray thank you thanks appreciate ask body bow five gesture hand high person prayer pressed together
✍️ writing hand lower left ballpoint pen stationery write compose body
💅 nail polish nail care beauty manicure finger fashion nail slay body cosmetics fingers nonchalant
🤳 selfie camera phone arm hand
💪 flexed biceps arm flex hand summer strong biceps bicep body comic feats flexing muscle muscles strength workout
🦾 mechanical arm accessibility body prosthetic
🦿 mechanical leg accessibility body prosthetic
🦵 leg kick limb body
🦶 foot kick stomp body
👂 ear face hear sound listen body ears hearing listening nose
🦻 ear with hearing aid accessibility body hard
👃 nose smell sniff body smelling sniffing stinky
🧠 brain smart intelligent body organ
🦷 tooth teeth dentist body
🦴 bone skeleton body
👀 eyes look watch stalk peek see body eye eyeballs face shifty wide
👁️ eye face look see watch stare body single
👅 tongue mouth playful body out taste
👄 mouth kiss body kissing lips
👶 baby child boy girl toddler newborn young
🧒 child gender-neutral young boy gender girl inclusive neutral person unspecified
👦 boy man male guy teenager child young
👧 girl female woman teenager child maiden virgin virgo young zodiac
🧑 person gender-neutral adult female gender inclusive male man men neutral unspecified woman women
👱 person blond hair hairstyle blonde haired man
👨 man mustache father dad guy classy sir moustache adult male men
🧔 man beard person bewhiskered bearded
👨‍🦰 man red hair hairstyle adult ginger haired male men redhead
👨‍🦱 man curly hair hairstyle adult haired male men
👨‍🦳 man white hair old elder adult haired male men
👨‍🦲 man bald hairless adult hair male men no
👩 woman female girls lady adult women yellow
👩‍🦰 woman red hair hairstyle adult female ginger haired redhead women
🧑‍🦰 person red hair hairstyle adult gender haired unspecified
👩‍🦱 woman curly hair hairstyle adult female haired women
🧑‍🦱 person curly hair hairstyle adult gender haired unspecified
👩‍🦳 woman white hair old elder adult female haired women
🧑‍🦳 person white hair elder old adult gender haired unspecified
👩‍🦲 woman bald hairless adult female hair no women
🧑‍🦲 person bald hairless adult gender hair no unspecified
👱‍♀️ woman blond hair woman female girl blonde person haired women
👱‍♂️ man blond hair man male boy blonde guy person haired men
🧓 older person human elder senior gender-neutral adult female gender male man men neutral old unspecified woman women
👴 old man human male men old elder senior adult elderly grandpa older
👵 old woman human female women lady old elder senior adult elderly grandma nanna older
🙍 person frowning worried frown gesture sad woman
🙍‍♂️ man frowning male boy man sad depressed discouraged unhappy frown gesture men
🙍‍♀️ woman frowning female girl woman sad depressed discouraged unhappy frown gesture women
🙎 person pouting upset blank face fed gesture look up
🙎‍♂️ man pouting male boy man gesture men
🙎‍♀️ woman pouting female girl woman gesture women
🙅 person gesturing no decline arms deal denied face forbidden gesture good halt hand not ok prohibited stop x
🙅‍♂️ man gesturing no male boy man nope denied forbidden gesture good halt hand men ng not ok prohibited stop
🙅‍♀️ woman gesturing no female girl woman nope denied forbidden gesture good halt hand ng not ok prohibited stop women
🙆 person gesturing ok agree ballerina face gesture hand hands head
🙆‍♂️ man gesturing ok men boy male blue human man gesture hand
🙆‍♀️ woman gesturing ok women girl female pink human woman gesture hand
💁 person tipping hand information attendant bellhop concierge desk female flick girl hair help sassy woman women
💁‍♂️ man tipping hand male boy man human information desk help men sassy
💁‍♀️ woman tipping hand female girl woman human information desk help sassy women
🙋 person raising hand question answering gesture happy one raised up
🙋‍♂️ man raising hand male boy man gesture happy men one raised
🙋‍♀️ woman raising hand female girl woman gesture happy one raised women
🧏 deaf person accessibility ear hear
🧏‍♂️ deaf man accessibility male men
🧏‍♀️ deaf woman accessibility female women
🙇 person bowing respectiful apology bow boy cute deeply dogeza gesture man massage respect sorry thanks
🙇‍♂️ man bowing man male boy apology bow deeply favor gesture men respect sorry thanks
🙇‍♀️ woman bowing woman female girl apology bow deeply favor gesture respect sorry thanks women
🤦 person facepalming disappointed disbelief exasperation face facepalm head hitting palm picard smh
🤦‍♂️ man facepalming man male boy disbelief exasperation face facepalm men palm
🤦‍♀️ woman facepalming woman female girl disbelief exasperation face facepalm palm women
🤷 person shrugging regardless doubt ignorance indifference shrug shruggie ¯\
🤷‍♂️ man shrugging man male boy confused indifferent doubt ignorance indifference men shrug
🤷‍♀️ woman shrugging woman female girl confused indifferent doubt ignorance indifference shrug women
🧑‍⚕️ health worker hospital dentist doctor healthcare md nurse physician professional therapist
👨‍⚕️ man health worker doctor nurse therapist healthcare man human dentist male md men physician professional
👩‍⚕️ woman health worker doctor nurse therapist healthcare woman human dentist female md physician professional women
🧑‍🎓 student learn education graduate pupil school
👨‍🎓 man student graduate man human education graduation male men pupil school
👩‍🎓 woman student graduate woman human education female graduation pupil school women
🧑‍🏫 teacher professor education educator instructor
👨‍🏫 man teacher instructor professor man human education educator male men school
👩‍🏫 woman teacher instructor professor woman human education educator female school women
🧑‍⚖️ judge law court justice scales
👨‍⚖️ man judge justice court man human law male men scales
👩‍⚖️ woman judge justice court woman human female law scales women
🧑‍🌾 farmer crops farm farming gardener rancher worker
👨‍🌾 man farmer rancher gardener man human farm farming male men worker
👩‍🌾 woman farmer rancher gardener woman human farm farming female women worker
🧑‍🍳 cook food kitchen culinary chef cooking service
👨‍🍳 man cook chef man human cooking food male men service
👩‍🍳 woman cook chef woman human cooking female food service women
🧑‍🔧 mechanic worker technician electrician person plumber repair tradesperson
👨‍🔧 man mechanic plumber man human wrench electrician male men person repair tradesperson
👩‍🔧 woman mechanic plumber woman human wrench electrician female person repair tradesperson women
🧑‍🏭 factory worker labor assembly industrial welder
👨‍🏭 man factory worker assembly industrial man human male men welder
👩‍🏭 woman factory worker assembly industrial woman human female welder women
🧑‍💼 office worker business accountant adviser analyst architect banker clerk manager
👨‍💼 man office worker business manager man human accountant adviser analyst architect banker businessman ceo clerk male men
👩‍💼 woman office worker business manager woman human accountant adviser analyst architect banker businesswoman ceo clerk female women
🧑‍🔬 scientist chemistry biologist chemist engineer lab mathematician physicist technician
👨‍🔬 man scientist biologist chemist engineer physicist man human lab male mathematician men research technician
👩‍🔬 woman scientist biologist chemist engineer physicist woman human female lab mathematician research technician women
🧑‍💻 technologist computer coder engineer laptop software technology
👨‍💻 man technologist coder developer engineer programmer software man human laptop computer blogger male men technology
👩‍💻 woman technologist coder developer engineer programmer software woman human laptop computer blogger female technology women
🧑‍🎤 singer song artist performer actor entertainer music musician rock rocker rockstar star
👨‍🎤 man singer rockstar entertainer man human actor aladdin bowie male men music musician rock rocker sane star
👩‍🎤 woman singer rockstar entertainer woman human actor female music musician rock rocker star women
🧑‍🎨 artist painting draw creativity art paint painter palette
👨‍🎨 man artist painter man human art male men paint palette
👩‍🎨 woman artist painter woman human art female paint palette women
🧑‍✈️ pilot fly plane airplane aviation aviator
👨‍✈️ man pilot aviator plane man human airplane aviation male men
👩‍✈️ woman pilot aviator plane woman human airplane aviation female women
🧑‍🚀 astronaut outerspace moon planets rocket space stars
👨‍🚀 man astronaut space rocket man human cosmonaut male men moon planets stars
👩‍🚀 woman astronaut space rocket woman human cosmonaut female moon planets stars women
🧑‍🚒 firefighter fire firetruck
👨‍🚒 man firefighter fireman man human fire firetruck male men
👩‍🚒 woman firefighter fireman woman human female fire firetruck women
👮 police officer cop law policeman policewoman
👮‍♂️ man police officer man police law legal enforcement arrest 911 cop male men policeman
👮‍♀️ woman police officer woman police law legal enforcement arrest 911 female cop policewoman women
🕵️ detective human spy eye or private sleuth
🕵️‍♂️ man detective crime male men sleuth spy
🕵️‍♀️ woman detective human spy detective female woman sleuth women
💂 guard protect british guardsman
💂‍♂️ man guard uk gb british male guy royal guardsman men
💂‍♀️ woman guard uk gb british female royal woman guardsman guardswoman women
👷 construction worker labor build builder face hard hat helmet safety
👷‍♂️ man construction worker male human wip guy build construction worker labor helmet men
👷‍♀️ woman construction worker female human wip build construction worker labor woman helmet women
🤴 prince boy man male crown royal king fairy fantasy men tale
👸 princess girl woman female blond crown royal queen blonde fairy fantasy tale tiara women
👳 person wearing turban headdress arab man muslim sikh
👳‍♂️ man wearing turban male indian hinduism arabs men
👳‍♀️ woman wearing turban female indian hinduism arabs woman women
👲 man with skullcap male boy chinese asian cap gua hat mao person pi
🧕 woman with headscarf female hijab mantilla tichel
🤵 man in tuxedo couple marriage wedding groom male men person suit
👰 bride with veil couple marriage wedding woman bride person
🤰 pregnant woman baby female pregnancy pregnant lady women
🤱 breast feeding nursing baby breastfeeding child female infant milk mother woman women
👼 baby angel heaven wings halo cherub cupid face fairy fantasy putto tale
🎅 santa claus festival man male xmas father christmas activity celebration men nicholas saint sinterklaas
🤶 mrs claus woman female xmas mother christmas activity celebration mrs. santa women
🦸 superhero marvel fantasy good hero heroine superpower superpowers
🦸‍♂️ man superhero man male good hero superpowers fantasy men superpower
🦸‍♀️ woman superhero woman female good heroine superpowers fantasy hero superpower women
🦹 supervillain marvel bad criminal evil fantasy superpower superpowers villain
🦹‍♂️ man supervillain man male evil bad criminal hero superpowers fantasy men superpower villain
🦹‍♀️ woman supervillain woman female evil bad criminal heroine superpowers fantasy superpower villain women
🧙 mage magic fantasy sorcerer sorceress witch wizard
🧙‍♂️ man mage man male mage sorcerer fantasy men wizard
🧙‍♀️ woman mage woman female mage witch fantasy sorceress wizard women
🧚 fairy wings magical fantasy oberon puck titania
🧚‍♂️ man fairy man male fantasy men oberon puck
🧚‍♀️ woman fairy woman female fantasy titania wings women
🧛 vampire blood twilight dracula fantasy undead
🧛‍♂️ man vampire man male dracula fantasy men undead
🧛‍♀️ woman vampire woman female fantasy undead unded women
🧜 merperson sea fantasy merboy mergirl mermaid merman merwoman
🧜‍♂️ merman man male triton fantasy men mermaid
🧜‍♀️ mermaid woman female merwoman ariel fantasy women
🧝 elf magical ears fantasy legolas pointed
🧝‍♂️ man elf man male ears fantasy magical men pointed
🧝‍♀️ woman elf woman female ears fantasy magical pointed women
🧞 genie magical wishes djinn djinni fantasy jinni
🧞‍♂️ man genie man male djinn fantasy men
🧞‍♀️ woman genie woman female djinn fantasy women
🧟 zombie dead fantasy undead walking
🧟‍♂️ man zombie man male dracula undead walking dead fantasy men
🧟‍♀️ woman zombie woman female undead walking dead fantasy women
💆 person getting massage relax face head massaging salon spa
💆‍♂️ man getting massage male boy man head face men salon spa
💆‍♀️ woman getting massage female girl woman head face salon spa women
💇 person getting haircut hairstyle barber beauty cutting hair hairdresser parlor
💇‍♂️ man getting haircut male boy man barber beauty men parlor
💇‍♀️ woman getting haircut female girl woman barber beauty parlor women
🚶 person walking move hike pedestrian walk walker
🚶‍♂️ man walking human feet steps hike male men pedestrian walk
🚶‍♀️ woman walking human feet steps woman female hike pedestrian walk women
🧍 person standing still stand
🧍‍♂️ man standing still male men stand
🧍‍♀️ woman standing still female stand women
🧎 person kneeling pray respectful kneel
🧎‍♂️ man kneeling pray respectful kneel male men
🧎‍♀️ woman kneeling respectful pray female kneel women
🧑‍🦯 person with probing cane blind accessibility white
👨‍🦯 man with probing cane blind accessibility male men white
👩‍🦯 woman with probing cane blind accessibility female white women
🧑‍🦼 person in motorized wheelchair disability accessibility
👨‍🦼 man in motorized wheelchair disability accessibility male men
👩‍🦼 woman in motorized wheelchair disability accessibility female women
🧑‍🦽 person in manual wheelchair disability accessibility
👨‍🦽 man in manual wheelchair disability accessibility male men
👩‍🦽 woman in manual wheelchair disability accessibility female women
🏃 person running move exercise jogging marathon run runner workout
🏃‍♂️ man running man walking exercise race running male marathon men racing runner workout
🏃‍♀️ woman running woman walking exercise race running female boy marathon racing runner women workout
💃 woman dancing female girl woman fun dance dancer dress red salsa women
🕺 man dancing male boy fun dancer dance disco men
🕴️ man in suit levitating suit business levitate hover jump boy hovering jabsco male men person rude walt
👯 people with bunny ears perform costume dancer dancing ear partying wearing women
👯‍♂️ men with bunny ears male bunny men boys dancer dancing ear man partying wearing
👯‍♀️ women with bunny ears female bunny women girls dancer dancing ear partying people wearing
🧖 person in steamy room relax spa hamam sauna steam steambath
🧖‍♂️ man in steamy room male man spa steamroom sauna hamam men steam steambath
🧖‍♀️ woman in steamy room female woman spa steamroom sauna hamam steam steambath women
🧗 person climbing sport bouldering climber rock
🧗‍♂️ man climbing sports hobby man male rock bouldering climber men
🧗‍♀️ woman climbing sports hobby woman female rock bouldering climber women
🤺 person fencing sports fencing sword fencer
🏇 horse racing animal betting competition gambling luck jockey race racehorse
⛷️ skier sports winter snow ski
🏂 snowboarder sports winter ski snow snowboard snowboarding
🏌️ person golfing sports business ball club golf golfer
🏌️‍♂️ man golfing sport ball golf golfer male men
🏌️‍♀️ woman golfing sports business woman female ball golf golfer women
🏄 person surfing sport sea surf surfer
🏄‍♂️ man surfing sports ocean sea summer beach male men surfer
🏄‍♀️ woman surfing sports ocean sea summer beach woman female surfer women
🚣 person rowing boat sport move paddles rowboat vehicle
🚣‍♂️ man rowing boat sports hobby water ship male men rowboat vehicle
🚣‍♀️ woman rowing boat sports hobby water ship woman female rowboat vehicle women
🏊 person swimming sport pool swim swimmer
🏊‍♂️ man swimming sports exercise human athlete water summer male men swim swimmer
🏊‍♀️ woman swimming sports exercise human athlete water summer woman female swim swimmer women
⛹️ person bouncing ball sports human basketball player
⛹️‍♂️ man bouncing ball sport basketball male men player
⛹️‍♀️ woman bouncing ball sports human woman female basketball player women
🏋️ person lifting weights sports training exercise bodybuilder gym lifter weight weightlifter workout
🏋️‍♂️ man lifting weights sport gym lifter male men weight weightlifter workout
🏋️‍♀️ woman lifting weights sports training exercise woman female gym lifter weight weightlifter women workout
🚴 person biking bicycle bike cyclist sport move bicyclist
🚴‍♂️ man biking bicycle bike cyclist sports exercise hipster bicyclist male men
🚴‍♀️ woman biking bicycle bike cyclist sports exercise hipster woman female bicyclist women
🚵 person mountain biking bicycle bike cyclist sport move bicyclist biker
🚵‍♂️ man mountain biking bicycle bike cyclist transportation sports human race bicyclist biker male men
🚵‍♀️ woman mountain biking bicycle bike cyclist transportation sports human race woman female bicyclist biker women
🤸 person cartwheeling sport gymnastic cartwheel doing gymnast gymnastics
🤸‍♂️ man cartwheeling gymnastics cartwheel doing male men
🤸‍♀️ woman cartwheeling gymnastics cartwheel doing female women
🤼 people wrestling sport wrestle wrestler wrestlers
🤼‍♂️ men wrestling sports wrestlers male man wrestle wrestler
🤼‍♀️ women wrestling sports wrestlers female woman wrestle wrestler
🤽 person playing water polo sport
🤽‍♂️ man playing water polo sports pool male men
🤽‍♀️ woman playing water polo sports pool female women
🤾 person playing handball sport ball
🤾‍♂️ man playing handball sports ball male men
🤾‍♀️ woman playing handball sports ball female women
🤹 person juggling performance balance juggle juggler multitask skill
🤹‍♂️ man juggling juggle balance skill multitask juggler male men
🤹‍♀️ woman juggling juggle balance skill multitask female juggler women
🧘 person in lotus position meditate meditation serenity yoga
🧘‍♂️ man in lotus position man male meditation yoga serenity zen mindfulness men
🧘‍♀️ woman in lotus position woman female meditation yoga serenity zen mindfulness women
🛀 person taking bath clean shower bathroom bathing bathtub hot
🛌 person in bed bed rest accommodation hotel sleep sleeping
🧑‍🤝‍🧑 people holding hands friendship couple date gender hand hold inclusive neutral nonconforming
👭 women holding hands pair friendship couple love like female people human date hand hold lesbian lgbt pride two woman
👫 woman and man holding hands pair people human love date dating like affection valentines marriage couple female hand heterosexual hold male men straight women
👬 men holding hands pair couple love like bromance friendship people human date gay hand hold lgbt male man pride two
💏 kiss pair valentines love like dating marriage couple couplekiss female gender heart kissing male man men neutral romance woman women
👩‍❤️‍💋‍👨 kiss woman man love couple couplekiss female heart kissing male men romance women
👨‍❤️‍💋‍👨 kiss man man pair valentines love like dating marriage couple couplekiss gay heart kissing lgbt male men pride romance two
👩‍❤️‍💋‍👩 kiss woman woman pair valentines love like dating marriage couple couplekiss female heart kissing lesbian lgbt pride romance two women
💑 couple with heart pair love like affection human dating valentines marriage female gender loving male man men neutral romance woman women
👩‍❤️‍👨 couple with heart woman man love female male men romance women
👨‍❤️‍👨 couple with heart man man pair love like affection human dating valentines marriage gay lgbt male men pride romance two
👩‍❤️‍👩 couple with heart woman woman pair love like affection human dating valentines marriage female lesbian lgbt pride romance two women
👪 family home parents child mom dad father mother people human boy female male man men woman women
👨‍👩‍👦 family man woman boy love father mother son
👨‍👩‍👧 family man woman girl home parents people human child daughter father female male men mother women
👨‍👩‍👧‍👦 family man woman girl boy home parents people human children child daughter father female male men mother son women
👨‍👩‍👦‍👦 family man woman boy boy home parents people human children child father female male men mother sons two women
👨‍👩‍👧‍👧 family man woman girl girl home parents people human children child daughters father female male men mother two women
👨‍👨‍👦 family man man boy home parents people human children child father fathers gay lgbt male men pride son two
👨‍👨‍👧 family man man girl home parents people human children child daughter father fathers gay lgbt male men pride two
👨‍👨‍👧‍👦 family man man girl boy home parents people human children child daughter father fathers gay lgbt male men pride son two
👨‍👨‍👦‍👦 family man man boy boy home parents people human children child father fathers gay lgbt male men pride sons two
👨‍👨‍👧‍👧 family man man girl girl home parents people human children child daughters father fathers gay lgbt male men pride two
👩‍👩‍👦 family woman woman boy home parents people human children child female lesbian lgbt mother mothers pride son two women
👩‍👩‍👧 family woman woman girl home parents people human children child daughter female lesbian lgbt mother mothers pride two women
👩‍👩‍👧‍👦 family woman woman girl boy home parents people human children child daughter female lesbian lgbt mother mothers pride son two women
👩‍👩‍👦‍👦 family woman woman boy boy home parents people human children child female lesbian lgbt mother mothers pride sons two women
👩‍👩‍👧‍👧 family woman woman girl girl home parents people human children child daughters female lesbian lgbt mother mothers pride two women
👨‍👦 family man boy home parent people human child father male men son
👨‍👦‍👦 family man boy boy home parent people human children child father male men sons two
👨‍👧 family man girl home parent people human child daughter father female male
👨‍👧‍👦 family man girl boy home parent people human children child daughter father male men son
👨‍👧‍👧 family man girl girl home parent people human children child daughters father female male two
👩‍👦 family woman boy home parent people human child female mother son women
👩‍👦‍👦 family woman boy boy home parent people human children child female mother sons two women
👩‍👧 family woman girl home parent people human child daughter female mother women
👩‍👧‍👦 family woman girl boy home parent people human children child daughter female male mother son
👩‍👧‍👧 family woman girl girl home parent people human children child daughters female mother two women
🗣️ speaking head user person human sing say talk face mansplaining shout shouting silhouette speak
👤 bust in silhouette user person human shadow
👥 busts in silhouette user person human group team bust people shadows silhouettes two users
👣 footprints feet tracking walking beach body clothing footprint footsteps print tracks
🐵 monkey face animal nature circus head
🐒 monkey animal nature banana circus cheeky
🦍 gorilla animal nature circus
🦧 orangutan animal ape
🐶 dog face animal friend nature woof puppy pet faithful
🐕 dog animal nature friend doge pet faithful dog2 doggo
🦮 guide dog animal blind accessibility eye seeing
🐕‍🦺 service dog blind animal accessibility assistance
🐩 poodle dog animal 101 nature pet miniature standard toy
🐺 wolf animal nature wild face
🦊 fox animal nature face
🦝 raccoon animal nature curious face sly
🐱 cat face animal meow nature pet kitten kitty
🐈 cat animal meow pet cats cat2 domestic feline housecat
🦁 lion animal nature face leo zodiac
🐯 tiger face animal cat danger wild nature roar cute
🐅 tiger animal nature roar bengal tiger2
🐆 leopard animal nature african jaguar
🐴 horse face animal brown nature head
🐎 horse animal gamble luck equestrian galloping racehorse racing speed
🦄 unicorn animal nature mystical face
🦓 zebra animal nature stripes safari face stripe
🦌 deer animal nature horns venison buck reindeer stag
🐮 cow face beef ox animal nature moo milk happy
🐂 ox animal cow beef bull bullock oxen steer taurus zodiac
🐃 water buffalo animal nature ox cow domestic
🐄 cow beef ox animal nature moo milk cow2 dairy
🐷 pig face animal oink nature head
🐖 pig animal nature hog pig2 sow
🐗 boar animal nature pig warthog wild
🐽 pig nose animal oink face snout
🐏 ram animal sheep nature aries male zodiac
🐑 ewe animal nature wool shipit female lamb sheep
🐐 goat animal nature capricorn zodiac
🐪 camel animal hot desert hump arabian bump dromedary one
🐫 two hump camel animal nature hot desert hump asian bactrian bump
🦙 llama animal nature alpaca guanaco vicuña wool
🦒 giraffe animal nature spots safari face
🐘 elephant animal nature nose th circus
🦏 rhinoceros animal nature horn rhino
🦛 hippopotamus animal nature hippo
🐭 mouse face animal nature cheese wedge rodent
🐁 mouse animal nature rodent dormouse mice mouse2
🐀 rat animal mouse rodent
🐹 hamster animal nature face pet
🐰 rabbit face animal nature pet spring magic bunny easter
🐇 rabbit animal nature pet magic spring bunny rabbit2
🐿️ chipmunk animal nature rodent squirrel
🦔 hedgehog animal nature spiny face
🦇 bat animal nature blind vampire batman
🐻 bear animal nature wild face teddy
🐨 koala animal nature bear face marsupial
🐼 panda animal nature face
🦥 sloth animal lazy slow
🦦 otter animal fishing playful
🦨 skunk animal smelly stink
🦘 kangaroo animal nature australia joey hop marsupial jump roo
🦡 badger animal nature honey pester
🐾 paw prints animal tracking footprints dog cat pet feet kitten print puppy
🦃 turkey animal bird thanksgiving wild
🐔 chicken animal cluck nature bird hen
🐓 rooster animal nature chicken bird cock cockerel
🐣 hatching chick animal chicken egg born baby bird
🐤 baby chick animal chicken bird yellow
🐥 front facing baby chick animal chicken baby bird hatched standing
🐦 bird animal nature fly tweet spring
🐧 penguin animal nature bird
🕊️ dove animal bird fly peace
🦅 eagle animal nature bird bald
🦆 duck animal nature bird mallard
🦢 swan animal nature bird cygnet duckling ugly
🦉 owl animal nature bird hoot wise
🦩 flamingo animal flamboyant tropical
🦚 peacock animal nature peahen bird ostentatious proud
🦜 parrot animal nature bird pirate talk
🐸 frog animal nature croak toad face
🐊 crocodile animal nature reptile lizard alligator croc
🐢 turtle animal slow nature tortoise terrapin
🦎 lizard animal nature reptile gecko
🐍 snake animal evil nature hiss python bearer ophiuchus serpent zodiac
🐲 dragon face animal myth nature chinese green fairy head tale
🐉 dragon animal myth nature chinese green fairy tale
🦕 sauropod animal nature dinosaur brachiosaurus brontosaurus diplodocus extinct
🦖 t rex animal nature dinosaur tyrannosaurus extinct trex
🐳 spouting whale animal nature sea ocean cute face fish
🐋 whale animal nature sea ocean fish
🐬 dolphin animal nature fish sea ocean flipper fins beach
🐟 fish animal food nature freshwater pisces zodiac
🐠 tropical fish animal swim ocean beach nemo blue yellow
🐡 blowfish animal nature food sea ocean fish fugu pufferfish
🦈 shark animal nature fish sea ocean jaws fins beach great white
🐙 octopus animal creature ocean sea nature beach
🐚 spiral shell nature sea beach seashell
🐌 snail slow animal shell garden slug
🦋 butterfly animal insect nature caterpillar pretty
🐛 bug animal insect nature worm caterpillar
🐜 ant animal insect nature bug
🐝 honeybee animal insect nature bug spring honey bee bumblebee
🐞 lady beetle animal insect nature ladybug bug ladybird
🦗 cricket animal chirp grasshopper insect orthoptera
🕷️ spider animal arachnid insect
🕸️ spider web animal insect arachnid silk cobweb spiderweb
🦂 scorpion animal arachnid scorpio scorpius zodiac
🦟 mosquito animal nature insect malaria disease fever pest virus
🦠 microbe amoeba bacteria germs virus covid cell coronavirus germ microorganism
💐 bouquet flowers nature spring flower plant romance
🌸 cherry blossom nature plant spring flower pink sakura
💮 white flower japanese spring blossom cherry doily done paper stamp well
🏵️ rosette flower decoration military plant
🌹 rose flowers valentines love spring flower plant red
🥀 wilted flower plant nature flower rose dead drooping
🌺 hibiscus plant vegetable flowers beach flower
🌻 sunflower nature plant fall flower sun yellow
🌼 blossom nature flowers yellow blossoming flower daisy flower plant
🌷 tulip flowers plant nature summer spring flower
🌱 seedling plant nature grass lawn spring sprout sprouting young
🌲 evergreen tree plant nature fir pine wood
🌳 deciduous tree plant nature rounded shedding wood
🌴 palm tree plant vegetable nature summer beach mojito tropical coconut
🌵 cactus vegetable plant nature desert
🌾 sheaf of rice nature plant crop ear farming grain wheat
🌿 herb vegetable plant medicine weed grass lawn crop leaf
☘️ shamrock vegetable plant nature irish clover trefoil
🍀 four leaf clover vegetable plant nature lucky irish ireland luck
🍁 maple leaf nature plant vegetable ca fall canada canadian falling
🍂 fallen leaf nature plant vegetable leaves autumn brown fall falling
🍃 leaf fluttering in wind nature plant tree vegetable grass lawn spring blow flutter green leaves
🍇 grapes fruit food wine grape plant
🍈 melon fruit nature food cantaloupe honeydew muskmelon plant
🍉 watermelon fruit food picnic summer plant
🍊 tangerine food fruit nature orange mandarin plant
🍋 lemon fruit nature citrus lemonade plant
🍌 banana fruit food monkey plant plantain
🍍 pineapple fruit nature food plant
🥭 mango fruit food tropical
🍎 red apple fruit mac school delicious plant
🍏 green apple fruit nature delicious golden granny plant smith
🍐 pear fruit nature food plant
🍑 peach fruit nature food bottom butt plant
🍒 cherries food fruit berries cherry plant red wild
🍓 strawberry fruit food nature berry plant
🥝 kiwi fruit fruit food chinese gooseberry kiwifruit
🍅 tomato fruit vegetable nature food plant
🥥 coconut fruit nature food palm cocoanut colada piña
🥑 avocado fruit food
🍆 eggplant vegetable nature food aubergine phallic plant purple
🥔 potato food tuber vegatable starch baked idaho vegetable
🥕 carrot vegetable food orange
🌽 ear of corn food vegetable plant cob maize maze
🌶️ hot pepper food spicy chilli chili plant
🥒 cucumber fruit food pickle gherkin vegetable
🥬 leafy green food vegetable plant bok choy cabbage kale lettuce chinese cos greens romaine
🥦 broccoli fruit food vegetable cabbage wild
🧄 garlic food spice cook flavoring plant vegetable
🧅 onion cook food spice flavoring plant vegetable
🍄 mushroom plant vegetable fungus shroom toadstool
🥜 peanuts food nut nuts peanut vegetable
🌰 chestnut food squirrel acorn nut plant
🍞 bread food wheat breakfast toast loaf
🥐 croissant food bread french breakfast crescent roll
🥖 baguette bread food bread french france bakery
🥨 pretzel food bread twisted germany bakery soft twist
🥯 bagel food bread bakery schmear jewish bakery breakfast cheese cream
🥞 pancakes food breakfast flapjacks hotcakes brunch crêpe crêpes hotcake pancake
🧇 waffle food breakfast brunch indecisive iron
🧀 cheese wedge food chadder swiss
🍖 meat on bone good food drumstick barbecue bbq manga
🍗 poultry leg food meat drumstick bird chicken turkey bone
🥩 cut of meat food cow meat cut chop lambchop porkchop steak
🥓 bacon food breakfast pork pig meat brunch rashers
🍔 hamburger meat fast food beef cheeseburger mcdonalds burger king
🍟 french fries chips snack fast food potato mcdonald's
🍕 pizza food party italy cheese pepperoni slice
🌭 hot dog food frankfurter america hotdog redhot sausage wiener
🥪 sandwich food lunch bread toast bakery cheese deli meat vegetables
🌮 taco food mexican
🌯 burrito food mexican wrap
🥙 stuffed flatbread food flatbread stuffed gyro mediterranean doner falafel kebab pita sandwich shawarma
🧆 falafel food mediterranean chickpea falfel meatball
🥚 egg food chicken breakfast
🍳 cooking food breakfast kitchen egg skillet fried frying pan
🥘 shallow pan of food food cooking casserole paella skillet curry
🍲 pot of food food meat soup hot pot bowl stew
🥣 bowl with spoon food breakfast cereal oatmeal porridge congee tableware
🥗 green salad food healthy lettuce vegetable
🍿 popcorn food movie theater films snack drama corn popping
🧈 butter food cook dairy
🧂 salt condiment shaker
🥫 canned food food soup tomatoes can preserve tin tinned
🍱 bento box food japanese box lunch
🍘 rice cracker food japanese snack senbei
🍙 rice ball food japanese onigiri omusubi
🍚 cooked rice food asian boiled bowl steamed
🍛 curry rice food spicy hot indian
🍜 steaming bowl food japanese noodle chopsticks ramen noodles soup
🍝 spaghetti food italian pasta noodle
🍠 roasted sweet potato food nature plant goguma yam
🍢 oden skewer food japanese kebab seafood stick
🍣 sushi food fish japanese rice sashimi seafood
🍤 fried shrimp food animal appetizer summer prawn tempura
🍥 fish cake with swirl food japan sea beach narutomaki pink swirl kamaboko surimi ramen design fishcake pastry
🥮 moon cake food autumn dessert festival mooncake yuèbǐng
🍡 dango food dessert sweet japanese barbecue meat balls green pink skewer stick white
🥟 dumpling food empanada pierogi potsticker gyoza gyōza jiaozi
🥠 fortune cookie food prophecy dessert
🥡 takeout box food leftovers chinese container out oyster pail take
🦀 crab animal crustacean cancer zodiac
🦞 lobster animal nature bisque claws seafood
🦐 shrimp animal ocean nature seafood food prawn shellfish small
🦑 squid animal nature ocean sea food molusc
🦪 oyster food diving pearl
🍦 soft ice cream food hot dessert summer icecream mr. serve sweet whippy
🍧 shaved ice hot dessert summer cone snow sweet
🍨 ice cream food hot dessert bowl sweet
🍩 doughnut food dessert snack sweet donut breakfast
🍪 cookie food snack oreo chocolate sweet dessert biscuit chip
🎂 birthday cake food dessert cake candles celebration party pastry sweet
🍰 shortcake food dessert cake pastry piece slice strawberry sweet
🧁 cupcake food dessert bakery sweet cake fairy pastry
🥧 pie food dessert pastry filling sweet
🍫 chocolate bar food snack dessert sweet candy
🍬 candy snack dessert sweet lolly
🍭 lollipop food snack candy sweet dessert lollypop sucker
🍮 custard dessert food pudding flan caramel creme sweet
🍯 honey pot bees sweet kitchen honeypot
🍼 baby bottle food container milk drink feeding
🥛 glass of milk beverage drink cow
☕ hot beverage beverage caffeine latte espresso coffee mug cafe chocolate drink steaming tea
🍵 teacup without handle drink bowl breakfast green british beverage cup matcha tea
🍶 sake wine drink drunk beverage japanese alcohol booze bar bottle cup rice
🍾 bottle with popping cork drink wine bottle celebration bar bubbly champagne party sparkling
🍷 wine glass drink beverage drunk alcohol booze bar red
🍸 cocktail glass drink drunk alcohol beverage booze mojito bar martini
🍹 tropical drink beverage cocktail summer beach alcohol booze mojito bar fruit punch tiki vacation
🍺 beer mug relax beverage drink drunk party pub summer alcohol booze bar stein
🍻 clinking beer mugs relax beverage drink drunk party pub summer alcohol booze bar beers cheers clink drinks mug
🥂 clinking glasses beverage drink party alcohol celebrate cheers wine champagne toast celebration clink glass
🥃 tumbler glass drink beverage drunk alcohol liquor booze bourbon scotch whisky glass shot rum whiskey
🥤 cup with straw drink soda go juice malt milkshake pop smoothie soft tableware water
🧃 beverage box drink juice straw sweet
🧉 mate drink tea beverage bombilla chimarrão cimarrón maté yerba
🧊 ice water cold cube iceberg
🥢 chopsticks food hashi jeotgarak kuaizi
🍽️ fork and knife with plate food eat meal lunch dinner restaurant cooking cutlery dining tableware
🍴 fork and knife cutlery kitchen cooking silverware tableware
🥄 spoon cutlery kitchen tableware
🔪 kitchen knife knife blade cutlery kitchen weapon butchers chop cooking cut hocho tool
🏺 amphora vase jar aquarius cooking drink jug tool zodiac
🌍 globe showing europe africa globe world earth international planet
🌎 globe showing americas globe world USA earth international planet
🌏 globe showing asia australia globe world east earth international planet
🌐 globe with meridians earth international world internet interweb i18n global web wide www
🗺️ world map location direction travel
🗾 map of japan nation country japanese asia silhouette
🧭 compass magnetic navigation orienteering
🏔️ snow capped mountain photo nature environment winter cold
⛰️ mountain photo nature environment
🌋 volcano photo nature disaster eruption mountain weather
🗻 mount fuji photo mountain nature japanese capped san snow
🏕️ camping photo outdoors tent campsite
🏖️ beach with umbrella weather summer sunny sand mojito
🏜️ desert photo warm saharah
🏝️ desert island photo tropical mojito
🏞️ national park photo environment nature
🏟️ stadium photo place sports concert venue grandstand sport
🏛️ classical building art culture history
🏗️ building construction wip working progress crane
🧱 brick bricks clay construction mortar wall
🏘️ houses buildings photo building group house
🏚️ derelict house abandon evict broken building abandoned haunted old
🏠 house building home
🏡 house with garden home plant nature building tree
🏢 office building building bureau work city high rise
🏣 japanese post office building envelope communication japan mark postal
🏤 post office building email european
🏥 hospital building health surgery doctor cross emergency medical medicine red room
🏦 bank building money sales cash business enterprise bakkureru bk branch
🏨 hotel building accomodation checkin accommodation h
🏩 love hotel like affection dating building heart hospital
🏪 convenience store building shopping groceries corner e eleven® hour kwik mart shop
🏫 school building student education learn teach clock elementary high middle tower
🏬 department store building shopping mall center shops
🏭 factory building industry pollution smoke industrial smog
🏯 japanese castle photo building fortress
🏰 castle building royalty history european turrets
💒 wedding love like affection couple marriage bride groom activity chapel church heart romance
🗼 tokyo tower photo japanese eiffel red
🗽 statue of liberty american newyork new york
⛪ church building religion christ christian cross
🕌 mosque islam worship minaret domed muslim religion roof
🛕 hindu temple religion
🕍 synagogue judaism worship temple jewish jew religion synagog
⛩️ shinto shrine temple japan kyoto kami michi no religion
🕋 kaaba mecca mosque islam muslim religion
⛲ fountain photo summer water fresh feature park
⛺ tent photo camping outdoors
🌁 foggy photo mountain bridge city fog fog bridge karl under weather
🌃 night with stars evening city downtown star starry weather
🏙️ cityscape photo night life urban building city skyline
🌄 sunrise over mountains view vacation photo morning mountain sun weather
🌅 sunrise morning view vacation photo sun sunset weather
🌆 cityscape at dusk photo evening sky buildings building city landscape orange sun sunset weather
🌇 sunset photo good morning dawn building buildings city dusk over sun sunrise weather
🌉 bridge at night photo sanfrancisco gate golden weather
♨️ hot springs bath warm relax hotsprings onsen steam steaming
🎠 carousel horse photo carnival activity entertainment fairground go merry round
🎡 ferris wheel photo carnival londoneye activity amusement big entertainment fairground observation park
🎢 roller coaster carnival playground photo fun activity amusement entertainment park rollercoaster theme
💈 barber pole hair salon style barber's haircut hairdresser shop stripes
🎪 circus tent festival carnival party activity big entertainment top
🚂 locomotive transportation vehicle train engine railway steam
🚃 railway car transportation vehicle carriage electric railcar railroad train tram trolleybus wagon
🚄 high speed train transportation vehicle bullettrain railway shinkansen side
🚅 bullet train transportation vehicle speed fast public travel bullettrain front high nose railway shinkansen
🚆 train transportation vehicle diesel electric passenger railway regular train2
🚇 metro transportation blue-square mrt underground tube subway train vehicle
🚈 light rail transportation vehicle railway
🚉 station transportation vehicle public platform railway train
🚊 tram transportation vehicle trolleybus
🚝 monorail transportation vehicle
🚞 mountain railway transportation vehicle car funicular train
🚋 tram car transportation vehicle carriage public travel train trolleybus
🚌 bus car vehicle transportation school
🚍 oncoming bus vehicle transportation front
🚎 trolleybus bart transportation vehicle bus electric bus tram trolley
🚐 minibus vehicle car transportation bus minivan mover people
🚑 ambulance health 911 hospital vehicle
🚒 fire engine transportation cars vehicle department truck
🚓 police car vehicle cars transportation law legal enforcement cop patrol side
🚔 oncoming police car vehicle law legal enforcement 911 front of 🚓 cop
🚕 taxi uber vehicle cars transportation new side taxicab york
🚖 oncoming taxi vehicle cars uber front taxicab
🚗 automobile red transportation vehicle car side
🚘 oncoming automobile car vehicle transportation front
🚙 sport utility vehicle transportation vehicle blue campervan car motorhome recreational rv
🚚 delivery truck cars transportation vehicle
🚛 articulated lorry vehicle cars transportation express green semi truck
🚜 tractor vehicle car farming agriculture farm
🏎️ racing car sports race fast formula f1 one
🏍️ motorcycle race sports fast motorbike racing
🛵 motor scooter vehicle vespa sasha bike cycle
🦽 manual wheelchair accessibility
🦼 motorized wheelchair accessibility
🛺 auto rickshaw move transportation tuk
🚲 bicycle bike sports exercise hipster push vehicle
🛴 kick scooter vehicle kick razor
🛹 skateboard board skate
🚏 bus stop transportation wait busstop
🛣️ motorway road cupertino interstate highway
🛤️ railway track train transportation
🛢️ oil drum barrell
⛽ fuel pump gas station petroleum diesel fuelpump petrol
🚨 police car light police ambulance 911 emergency alert error pinged law legal beacon cars car’s emergency light flashing revolving rotating siren vehicle
🚥 horizontal traffic light transportation signal
🚦 vertical traffic light transportation driving semaphore signal
🛑 stop sign stop octagonal
🚧 construction wip progress caution warning barrier black roadwork sign striped yellow
⚓ anchor ship ferry sea boat admiralty fisherman pattern tool
⛵ sailboat ship summer transportation water sailing boat dinghy resort sea vehicle yacht
🛶 canoe boat paddle water ship
🚤 speedboat ship transportation vehicle summer boat motorboat powerboat
🛳️ passenger ship yacht cruise ferry vehicle
⛴️ ferry boat ship yacht passenger
🛥️ motor boat ship motorboat vehicle
🚢 ship transportation titanic deploy boat cruise passenger vehicle
✈️ airplane vehicle transportation flight fly aeroplane plane
🛩️ small airplane flight transportation fly vehicle aeroplane plane
🛫 airplane departure airport flight landing aeroplane departures off plane taking vehicle
🛬 airplane arrival airport flight boarding aeroplane arrivals arriving landing plane vehicle
🪂 parachute fly glide hang parasail skydive
💺 seat sit airplane transport bus flight fly aeroplane chair train
🚁 helicopter transportation vehicle fly
🚟 suspension railway vehicle transportation
🚠 mountain cableway transportation vehicle ski cable gondola
🚡 aerial tramway transportation vehicle ski cable car gondola ropeway
🛰️ satellite communication gps orbit spaceflight NASA ISS artificial space vehicle
🚀 rocket launch ship staffmode NASA outer space outer space fly shuttle vehicle
🛸 flying saucer transportation vehicle ufo alien extraterrestrial fantasy space
🛎️ bellhop bell service hotel
🧳 luggage packing travel suitcase
⌛ hourglass done time clock oldschool limit exam quiz test sand timer
⏳ hourglass not done oldschool time countdown flowing sand timer
⌚ watch time accessories apple clock timepiece wrist wristwatch
⏰ alarm clock time wake morning
⏱️ stopwatch time deadline clock
⏲️ timer clock alarm
🕰️ mantelpiece clock time
🕛 twelve o clock 12 00:00 0000 12:00 1200 time noon midnight midday late early schedule clock12 face oclock o’clock
🕧 twelve thirty 00:30 0030 12:30 1230 time late early schedule clock clock1230 face
🕐 one o clock 1 1:00 100 13:00 1300 time late early schedule clock1 face oclock o’clock
🕜 one thirty 1:30 130 13:30 1330 time late early schedule clock clock130 face
🕑 two o clock 2 2:00 200 14:00 1400 time late early schedule clock2 face oclock o’clock
🕝 two thirty 2:30 230 14:30 1430 time late early schedule clock clock230 face
🕒 three o clock 3 3:00 300 15:00 1500 time late early schedule clock3 face oclock o’clock
🕞 three thirty 3:30 330 15:30 1530 time late early schedule clock clock330 face
🕓 four o clock 4 4:00 400 16:00 1600 time late early schedule clock4 face oclock o’clock
🕟 four thirty 4:30 430 16:30 1630 time late early schedule clock clock430 face
🕔 five o clock 5 5:00 500 17:00 1700 time late early schedule clock5 face oclock o’clock
🕠 five thirty 5:30 530 17:30 1730 time late early schedule clock clock530 face
🕕 six o clock 6 6:00 600 18:00 1800 time late early schedule dawn dusk clock6 face oclock o’clock
🕡 six thirty 6:30 630 18:30 1830 time late early schedule clock clock630 face
🕖 seven o clock 7 7:00 700 19:00 1900 time late early schedule clock7 face oclock o’clock
🕢 seven thirty 7:30 730 19:30 1930 time late early schedule clock clock730 face
🕗 eight o clock 8 8:00 800 20:00 2000 time late early schedule clock8 face oclock o’clock
🕣 eight thirty 8:30 830 20:30 2030 time late early schedule clock clock830 face
🕘 nine o clock 9 9:00 900 21:00 2100 time late early schedule clock9 face oclock o’clock
🕤 nine thirty 9:30 930 21:30 2130 time late early schedule clock clock930 face
🕙 ten o clock 10 10:00 1000 22:00 2200 time late early schedule clock10 face oclock o’clock
🕥 ten thirty 10:30 1030 22:30 2230 time late early schedule clock clock1030 face
🕚 eleven o clock 11 11:00 1100 23:00 2300 time late early schedule clock11 face oclock o’clock
🕦 eleven thirty 11:30 1130 23:30 2330 time late early schedule clock clock1130 face
🌑 new moon nature twilight planet space night evening sleep dark eclipse shadow moon solar symbol weather
🌒 waxing crescent moon nature twilight planet space night evening sleep symbol weather
🌓 first quarter moon nature twilight planet space night evening sleep symbol weather
🌔 waxing gibbous moon nature night sky gray twilight planet space evening sleep symbol weather
🌕 full moon nature yellow twilight planet space night evening sleep symbol weather
🌖 waning gibbous moon nature twilight planet space night evening sleep waxing gibbous moon symbol weather
🌗 last quarter moon nature twilight planet space night evening sleep symbol weather
🌘 waning crescent moon nature twilight planet space night evening sleep symbol weather
🌙 crescent moon night sleep sky evening magic space weather
🌚 new moon face nature twilight planet space night evening sleep creepy dark molester weather
🌛 first quarter moon face nature twilight planet space night evening sleep weather
🌜 last quarter moon face nature twilight planet space night evening sleep weather
🌡️ thermometer weather temperature hot cold
☀️ sun weather nature brightness summer beach spring black bright rays space sunny sunshine
🌝 full moon face nature twilight planet space night evening sleep bright moonface smiley smiling weather
🌞 sun with face nature morning sky bright smiley smiling space summer sunface weather
🪐 ringed planet outerspace planets saturn saturnine space
⭐ star night yellow gold medium white
🌟 glowing star night sparkle awesome good magic glittery glow shining star2
🌠 shooting star night photo activity falling meteoroid space stars upon when wish you
🌌 milky way photo space stars galaxy night sky universe weather
☁️ cloud weather sky cloudy overcast
⛅ sun behind cloud weather nature cloudy morning fall spring partly sunny
⛈️ cloud with lightning and rain weather lightning thunder
🌤️ sun behind small cloud weather white
🌥️ sun behind large cloud weather white
🌦️ sun behind rain cloud weather white
🌧️ cloud with rain weather
🌨️ cloud with snow weather cold
🌩️ cloud with lightning weather thunder
🌪️ tornado weather cyclone twister cloud whirlwind
🌫️ fog weather cloud
🌬️ wind face gust air blow blowing cloud mother nature weather
🌀 cyclone weather swirl blue cloud vortex spiral whirlpool spin tornado hurricane typhoon dizzy twister
🌈 rainbow nature happy unicorn face photo sky spring gay lgbt pride primary rain weather
🌂 closed umbrella weather rain drizzle clothing collapsed umbrella pink
☂️ umbrella weather spring clothing open rain
☔ umbrella with rain drops rainy weather spring clothing drop raining
⛱️ umbrella on ground weather summer beach parasol rain sun
⚡ high voltage thunder weather lightning bolt fast zap danger electric electricity sign thunderbolt
❄️ snowflake winter season cold weather christmas xmas snow snowing
☃️ snowman winter season cold weather christmas xmas frozen snow snowflakes snowing
⛄ snowman without snow winter season cold weather christmas xmas frozen without snow frosty olaf
☄️ comet space
🔥 fire hot cook flame burn lit snapstreak tool
💧 droplet water drip faucet spring cold comic drop sweat weather
🌊 water wave sea water wave nature tsunami disaster beach ocean waves weather
🎃 jack o lantern halloween light pumpkin creepy fall activity celebration entertainment gourd
🎄 christmas tree festival vacation december xmas celebration activity entertainment xmas tree
🎆 fireworks photo festival carnival congratulations activity celebration entertainment explosion
🎇 sparkler stars night shine activity celebration entertainment firework fireworks hanabi senko sparkle
🧨 firecracker dynamite boom explode explosion explosive fireworks
✨ sparkles stars shine shiny cool awesome good magic entertainment glitter sparkle star
🎈 balloon party celebration birthday circus activity entertainment red
🎉 party popper party congratulations birthday magic circus celebration tada activity entertainment hat hooray
🎊 confetti ball festival party birthday circus activity celebration entertainment
🎋 tanabata tree plant nature branch summer bamboo wish star festival tanzaku activity banner celebration entertainment japanese
🎍 pine decoration japanese plant nature vegetable panda new years bamboo activity celebration kadomatsu year
🎎 japanese dolls japanese toy kimono activity celebration doll entertainment festival hinamatsuri imperial
🎏 carp streamer fish japanese koinobori carp banner activity celebration entertainment flag flags socks wind
🎐 wind chime nature ding spring bell activity celebration entertainment furin jellyfish
🎑 moon viewing ceremony photo japan asia tsukimi activity autumn celebration dumplings entertainment festival grass harvest mid rice scene
🧧 red envelope gift ang good hóngbāo lai luck money packet pao see
🎀 ribbon decoration pink girl bowtie bow celebration
🎁 wrapped gift present birthday christmas xmas box celebration entertainment
🎗️ reminder ribbon sports cause support awareness celebration
🎟️ admission tickets sports concert entrance entertainment ticket
🎫 ticket event concert pass activity admission entertainment stub tour world
🎖️ military medal award winning army celebration decoration medallion
🏆 trophy win award contest place ftw ceremony championship prize winner winners
🏅 sports medal award winning gold winner
🥇 1st place medal award winning first gold
🥈 2nd place medal award second silver
🥉 3rd place medal award third bronze
⚽ soccer ball sports football
⚾ baseball sports balls ball softball
🥎 softball sports balls ball game glove sport underarm
🏀 basketball sports balls NBA ball hoop orange
🏐 volleyball sports balls ball game
🏈 american football sports balls NFL ball gridiron superbowl
🏉 rugby football sports team ball league union
🎾 tennis sports balls green ball racket racquet
🥏 flying disc sports frisbee ultimate game golf sport
🎳 bowling sports fun play ball game pin pins skittles ten
🏏 cricket game sports ball bat field
🏑 field hockey sports ball game stick
🏒 ice hockey sports game puck stick
🥍 lacrosse sports ball stick game goal sport
🏓 ping pong sports pingpong ball bat game paddle table tennis
🏸 badminton sports birdie game racquet shuttlecock
🥊 boxing glove sports fighting
🥋 martial arts uniform judo karate taekwondo
🥅 goal net sports
⛳ flag in hole sports business flag hole summer golf
⛸️ ice skate sports skating
🎣 fishing pole food hobby summer entertainment fish rod
🤿 diving mask sport ocean scuba snorkeling
🎽 running shirt play pageant athletics marathon sash singlet
🎿 skis sports winter cold snow boot ski skiing
🛷 sled sleigh luge toboggan sledge
🥌 curling stone sports game rock
🎯 direct hit game play bar target bullseye activity archery bull dart darts entertainment eye
🪀 yo yo toy fluctuate yoyo
🪁 kite wind fly soar toy
🎱 pool 8 ball pool hobby game luck magic 8ball billiard billiards cue eight snooker
🔮 crystal ball disco party magic circus fortune teller clairvoyant fairy fantasy psychic purple tale tool
🧿 nazar amulet bead charm boncuğu evil eye talisman
🎮 video game play console PS4 controller entertainment gamepad playstation u wii xbox
🕹️ joystick game play entertainment video
🎰 slot machine bet gamble vegas fruit machine luck casino activity gambling game poker
🎲 game die dice random tabletop play luck entertainment gambling
🧩 puzzle piece interlocking puzzle piece clue jigsaw
🧸 teddy bear plush stuffed plaything toy
♠️ spade suit poker cards suits magic black card game spades
♥️ heart suit poker cards magic suits black card game hearts
♦️ diamond suit poker cards magic suits black card diamonds game
♣️ club suit poker cards magic suits black card clubs game
♟️ chess pawn expendable black dupe game piece
🃏 joker poker cards game play magic black card entertainment playing wildcard
🀄 mahjong red dragon game play chinese kanji tile
🎴 flower playing cards game sunset red activity card deck entertainment hanafuda hwatu japanese of cards
🎭 performing arts acting theater drama activity art comedy entertainment greek logo mask masks theatre theatre masks tragedy
🖼️ framed picture photography art frame museum painting
🎨 artist palette design paint draw colors activity art entertainment museum painting
🧵 thread needle sewing spool string crafts
🧶 yarn ball crochet knit crafts
👓 glasses fashion accessories eyesight nerdy dork geek clothing eye eyeglasses eyewear
🕶️ sunglasses face cool accessories dark eye eyewear glasses
🥽 goggles eyes protection safety clothing eye swimming welding
🥼 lab coat doctor experiment scientist chemist clothing
🦺 safety vest protection emergency
👔 necktie shirt suitup formal fashion cloth business clothing tie
👕 t shirt fashion cloth casual shirt tee clothing polo tshirt
👖 jeans fashion shopping clothing denim pants trousers
🧣 scarf neck winter clothes clothing
🧤 gloves hands winter clothes clothing hand
🧥 coat jacket clothing
🧦 socks stockings clothes clothing pair stocking
👗 dress clothes fashion shopping clothing gown skirt
👘 kimono dress fashion women female japanese clothing dressing gown
🥻 sari dress clothing saree shari
🩱 one piece swimsuit fashion bathing clothing suit swim
🩲 briefs clothing bathing brief suit swim swimsuit underwear
🩳 shorts clothing bathing pants suit swim swimsuit underwear
👙 bikini swimming female woman girl fashion beach summer bathers clothing swim swimsuit
👚 woman s clothes fashion shopping bags female blouse clothing pink shirt womans woman’s
👛 purse fashion accessories money sales shopping clothing coin wallet
👜 handbag fashion accessory accessories shopping bag clothing purse women’s
👝 clutch bag bag accessories shopping clothing pouch small
🛍️ shopping bags mall buy purchase bag hotel
🎒 backpack student education bag activity rucksack satchel school
👞 man s shoe fashion male brown clothing dress mans man’s
👟 running shoe shoes sports sneakers athletic clothing runner sneaker sport tennis trainer
🥾 hiking boot backpacking camping hiking clothing
🥿 flat shoe ballet slip-on slipper clothing woman’s
👠 high heeled shoe fashion shoes female pumps stiletto clothing heel heels woman
👡 woman s sandal shoes fashion flip flops clothing heeled sandals shoe womans woman’s
🩰 ballet shoes dance clothing pointe shoe
👢 woman s boot shoes fashion boots clothing cowgirl heeled high knee shoe womans woman’s
👑 crown king kod leader royalty lord clothing queen royal
👒 woman s hat fashion accessories female lady spring bow clothing ladies womans woman’s
🎩 top hat magic gentleman classy circus activity clothing entertainment formal groom tophat wear
🎓 graduation cap school college degree university graduation cap hat legal learn education academic activity board celebration clothing graduate mortar square
🧢 billed cap cap baseball clothing hat
⛑️ rescue worker s helmet construction build aid cross face hat white worker’s
📿 prayer beads dhikr religious clothing necklace religion rosary
💄 lipstick female girl fashion woman cosmetics gloss lip makeup
💍 ring wedding propose marriage valentines diamond fashion jewelry gem engagement engaged romance
💎 gem stone blue ruby diamond jewelry gemstone jewel romance
🔇 muted speaker sound volume silence quiet cancellation mute off silent stroke
🔈 speaker low volume sound volume silence broadcast soft
🔉 speaker medium volume volume speaker broadcast low one reduce sound wave
🔊 speaker high volume volume noise noisy speaker broadcast entertainment increase loud sound three waves
📢 loudspeaker volume sound address announcement bullhorn communication loud megaphone pa public system
📣 megaphone sound speaker volume bullhorn cheering communication mega
📯 postal horn instrument music bugle communication entertainment french post
🔔 bell sound notification christmas xmas chime liberty ringer wedding
🔕 bell with slash sound volume mute quiet silent cancellation disabled forbidden muted no not notifications off prohibited ringer stroke
🎼 musical score treble clef compose activity entertainment music sheet
🎵 musical note score tone sound activity beamed eighth entertainment music notes pair quavers
🎶 musical notes music score activity entertainment multiple note singing
🎙️ studio microphone sing recording artist talkshow mic music podcast
🎚️ level slider scale music
🎛️ control knobs dial music
🎤 microphone sound music PA sing talkshow activity entertainment karaoke mic singing
🎧 headphone music score gadgets activity earbud earphone earphones entertainment headphones ipod
📻 radio communication music podcast program digital entertainment video wireless
🎷 saxophone music instrument jazz blues activity entertainment sax
🎸 guitar music instrument acoustic guitar activity bass electric entertainment rock
🎹 musical keyboard piano instrument compose activity entertainment music
🎺 trumpet music brass activity entertainment horn instrument jazz
🎻 violin music instrument orchestra symphony activity entertainment quartet smallest string world’s
🪕 banjo music instructment activity entertainment instrument stringed
🥁 drum music instrument drumsticks snare
📱 mobile phone technology apple gadgets dial cell communication iphone smartphone telephone
📲 mobile phone with arrow iphone incoming call calling cell communication left pointing receive rightwards telephone
☎️ telephone technology communication dial black phone rotary
📞 telephone receiver technology communication dial call handset phone
📟 pager bbcall oldschool 90s beeper bleeper communication
📠 fax machine communication technology facsimile
🔋 battery power energy sustain aa phone
🔌 electric plug charger power ac adaptor cable electricity
💻 laptop technology screen display monitor computer desktop notebook pc personal
🖥️ desktop computer technology computing screen imac
🖨️ printer paper ink computer
⌨️ keyboard technology computer type input text
🖱️ computer mouse click button three
🖲️ trackball technology trackpad computer
💽 computer disk technology record data disk 90s entertainment minidisc minidisk optical
💾 floppy disk oldschool technology save 90s 80s computer
💿 optical disk technology dvd disk disc 90s cd compact computer rom
📀 dvd cd disk disc computer entertainment optical rom video
🧮 abacus calculation count counting frame math
🎥 movie camera film record activity cinema entertainment hollywood video
🎞️ film frames movie cinema entertainment strip
📽️ film projector video tape record movie cinema entertainment
🎬 clapper board movie film record activity clapboard director entertainment slate
📺 television technology program oldschool show entertainment tv video
📷 camera gadgets photography digital entertainment photo video
📸 camera with flash photography gadgets photo video
📹 video camera film record camcorder entertainment
📼 videocassette record video oldschool 90s 80s entertainment tape vcr vhs
🔍 magnifying glass tilted left search zoom find detective icon mag magnifier pointing tool
🔎 magnifying glass tilted right search zoom find detective icon mag magnifier pointing tool
🕯️ candle fire wax light
💡 light bulb light electricity idea comic electric
🔦 flashlight dark camping sight night electric light tool torch
🏮 red paper lantern light paper halloween spooky asian bar izakaya japanese
🪔 diya lamp lighting oil
📔 notebook with decorative cover classroom notes record paper study book decorated
📕 closed book read library knowledge textbook learn red
📖 open book book read library knowledge literature learn study novel
📗 green book read library knowledge study textbook
📘 blue book read library knowledge learn study textbook
📙 orange book read library knowledge textbook study
📚 books literature library study book pile stack
📓 notebook stationery record notes paper study black book composition white
📒 ledger notes paper binder book bound notebook spiral yellow
📃 page with curl documents office paper curled curly page document
📜 scroll documents ancient history paper degree document parchment
📄 page facing up documents office paper information document printed
📰 newspaper press headline communication news paper
🗞️ rolled up newspaper press headline delivery news paper roll
📑 bookmark tabs favorite save order tidy mark marker
🔖 bookmark favorite label save mark price tag
🏷️ label sale tag
💰 money bag dollar payment coins sale cream moneybag moneybags rich
💴 yen banknote money sales japanese dollar currency bank banknotes bill note sign
💵 dollar banknote money sales bill currency american bank banknotes note sign
💶 euro banknote money sales dollar currency bank banknotes bill note sign
💷 pound banknote british sterling money sales bills uk england currency bank banknotes bill note quid sign twenty
💸 money with wings dollar bills payment sale bank banknote bill fly flying losing note
💳 credit card money sales dollar bill payment shopping amex bank club diners mastercard subscription visa
🧾 receipt accounting expenses bookkeeping evidence proof
💹 chart increasing with yen green-square graph presentation stats bank currency exchange growth market money rate rise sign trend upward upwards
💱 currency exchange money sales dollar travel bank
💲 heavy dollar sign money sales payment currency buck
✉️ envelope letter postal inbox communication email ✉ letter
📧 e mail communication inbox email letter symbol
📨 incoming envelope email inbox communication fast letter lines mail receive
📩 envelope with arrow email communication above down downwards insert letter mail outgoing sent
📤 outbox tray inbox email box communication letter mail sent
📥 inbox tray email documents box communication letter mail receive
📦 package mail gift cardboard box moving communication parcel shipping
📫 closed mailbox with raised flag email inbox communication mail postbox
📪 closed mailbox with lowered flag email communication inbox mail postbox
📬 open mailbox with raised flag email inbox communication mail postbox
📭 open mailbox with lowered flag email inbox communication mail no postbox
📮 postbox email letter envelope communication mail mailbox
🗳️ ballot box with ballot election vote voting
✏️ pencil stationery write paper writing school study lead pencil2
✒️ black nib pen stationery writing write fountain ✒ fountain
🖋️ fountain pen stationery writing write communication left lower
🖊️ pen stationery writing write ballpoint communication left lower
🖌️ paintbrush drawing creativity art brush communication left lower painting
🖍️ crayon drawing creativity communication left lower
📝 memo write documents stationery pencil paper writing legal exam quiz test study compose communication document memorandum note
💼 briefcase business documents work law legal job career suitcase
📁 file folder documents business office closed directory manilla
📂 open file folder documents load
🗂️ card index dividers organizing business stationery
📅 calendar schedule date day emoji july world
📆 tear off calendar schedule date planning day desk
🗒️ spiral notepad memo stationery note pad
🗓️ spiral calendar date schedule planning pad
📇 card index business stationery rolodex system
📈 chart increasing graph presentation stats recovery business economics money sales good success growth metrics pointing positive chart trend up upward upwards
📉 chart decreasing graph presentation stats recession business economics money sales bad failure down downwards down pointing metrics negative chart trend
📊 bar chart graph presentation stats metrics
📋 clipboard stationery documents
📌 pushpin stationery mark here location pin tack thumb
📍 round pushpin stationery location map here dropped pin red
📎 paperclip documents stationery clippy
🖇️ linked paperclips documents stationery communication link paperclip
📏 straight ruler stationery calculate length math school drawing architect sketch edge
📐 triangular ruler stationery math architect sketch set triangle
✂️ scissors stationery cut black cutting tool
🗃️ card file box business stationery
🗄️ file cabinet filing organizing
🗑️ wastebasket bin trash rubbish garbage toss basket can litter wastepaper
🔒 locked security password padlock closed lock private
🔓 unlocked privacy security lock open padlock unlock
🔏 locked with pen security secret fountain ink lock lock with nib privacy
🔐 locked with key security privacy closed lock secure
🔑 key lock door password gold
🗝️ old key lock door password clue
🔨 hammer tools build create claw handyman tool
🪓 axe tool chop cut hatchet split wood
⛏️ pick tools dig mining pickaxe tool
⚒️ hammer and pick tools build create tool
🛠️ hammer and wrench tools build create spanner tool
🗡️ dagger weapon knife
⚔️ crossed swords weapon
🔫 pistol violence weapon revolver gun handgun shoot squirt tool water
🏹 bow and arrow sports archer archery sagittarius tool zodiac
🛡️ shield protection security weapon
🔧 wrench tools diy ikea fix maintainer spanner tool
🔩 nut and bolt handy tools fix screw tool
⚙️ gear cog cogwheel tool
🗜️ clamp tool compress compression table vice winzip
⚖️ balance scale law fairness weight justice libra scales tool zodiac
🦯 probing cane accessibility blind white
🔗 link rings url chain hyperlink linked symbol
⛓️ chains lock arrest chain
🧰 toolbox tools diy fix maintainer mechanic chest tool
🧲 magnet attraction magnetic horseshoe
⚗️ alembic distilling science experiment chemistry tool
🧪 test tube chemistry experiment lab science chemist
🧫 petri dish bacteria biology culture lab biologist
🧬 dna biologist genetics life double evolution gene helix
🔬 microscope laboratory experiment zoomin science study investigate magnify tool
🔭 telescope stars space zoom science astronomy stargazing tool
📡 satellite antenna communication future radio space dish signal
💉 syringe health hospital drugs blood medicine needle doctor nurse shot sick tool vaccination vaccine
🩸 drop of blood period hurt harm wound bleed doctor donation injury medicine menstruation
💊 pill health medicine doctor pharmacy drug capsule drugs sick tablet
🩹 adhesive bandage heal aid band doctor medicine plaster
🩺 stethoscope health doctor heart medicine
🚪 door house entry exit doorway front
🛏️ bed sleep rest bedroom hotel
🛋️ couch and lamp read chill hotel lounge settee sofa
🪑 chair sit furniture seat
🚽 toilet restroom wc washroom bathroom potty loo
🚿 shower clean water bathroom bath head
🛁 bathtub clean shower bathroom bath bubble
🪒 razor cut sharp shave
🧴 lotion bottle moisturizer sunscreen shampoo
🧷 safety pin diaper punk rock
🧹 broom cleaning sweeping witch brush sweep
🧺 basket laundry farming picnic
🧻 roll of paper roll toilet towels
🧼 soap bar bathing cleaning lather soapdish
🧽 sponge absorbing cleaning porous
🧯 fire extinguisher quench extinguish
🛒 shopping cart trolley
🚬 cigarette kills tobacco joint smoke activity smoking symbol
⚰️ coffin vampire dead die death rip graveyard cemetery casket funeral box
⚱️ funeral urn dead die death rip ashes vase
🗿 moai rock easter island carving face human moyai statue stone
🏧 atm sign money sales cash blue-square payment bank automated machine teller
🚮 litter in bin sign blue-square sign human info its litterbox person place put symbol trash
🚰 potable water blue-square liquid restroom cleaning faucet drink drinking symbol tap thirst thirsty
♿ wheelchair symbol blue-square disabled accessibility access accessible bathroom
🚹 men s room toilet restroom wc blue-square gender male lavatory man mens men’s symbol
🚺 women s room purple-square woman female toilet loo restroom gender lavatory symbol wc womens womens toilet women’s
🚻 restroom blue-square toilet refresh wc gender bathroom lavatory sign
🚼 baby symbol orange-square child change changing nursery station
🚾 water closet toilet restroom blue-square lavatory wc
🛂 passport control custom blue-square border
🛃 customs passport border blue-square
🛄 baggage claim blue-square airport transport
🛅 left luggage blue-square travel baggage bag with key locked locker suitcase
⚠️ warning exclamation wip alert error problem issue sign symbol
🚸 children crossing school warning danger sign driving yellow-diamond child kids pedestrian traffic
⛔ no entry limit security privacy bad denied stop circle forbidden not prohibited traffic
🚫 prohibited forbid stop limit denied disallow circle backslash banned block crossed entry forbidden no not red restricted sign
🚳 no bicycles no bikes bicycle bike cyclist prohibited circle forbidden not sign vehicle
🚭 no smoking cigarette blue-square smell smoke forbidden not prohibited sign symbol
🚯 no littering trash bin garbage circle do forbidden litter not prohibited symbol
🚱 non potable water drink faucet tap circle drinking forbidden no not prohibited symbol
🚷 no pedestrians rules crossing walking circle forbidden not pedestrian people prohibited
📵 no mobile phones iphone mute circle cell communication forbidden not phone prohibited smartphones telephone
🔞 no one under eighteen 18 drink pub night minor circle age forbidden not nsfw prohibited restriction symbol underage
☢️ radioactive nuclear danger international radiation sign symbol
☣️ biohazard danger sign
⬆️ up arrow blue-square continue top direction black cardinal north pointing upwards
↗️ up right arrow blue-square point direction diagonal northeast east intercardinal north upper
➡️ right arrow blue-square next black cardinal direction east pointing rightwards right arrow
↘️ down right arrow blue-square direction diagonal southeast east intercardinal lower right arrow south
⬇️ down arrow blue-square direction bottom black cardinal downwards down arrow pointing south
↙️ down left arrow blue-square direction diagonal southwest intercardinal left arrow lower south west
⬅️ left arrow blue-square previous back black cardinal direction leftwards left arrow pointing west
↖️ up left arrow blue-square point direction diagonal northwest intercardinal left arrow north upper west
↕️ up down arrow blue-square direction way vertical arrows intercardinal northwest
↔️ left right arrow shape direction horizontal sideways arrows horizontal arrows
↩️ right arrow curving left back return blue-square undo enter curved email hook leftwards reply
↪️ left arrow curving right blue-square return rotate direction email forward hook rightwards right curved
⤴️ right arrow curving up blue-square direction top heading pointing rightwards then upwards
⤵️ right arrow curving down blue-square direction bottom curved downwards heading pointing rightwards then
🔃 clockwise vertical arrows sync cycle round repeat arrow circle downwards open reload upwards
🔄 counterclockwise arrows button blue-square sync cycle anticlockwise arrow circle downwards open refresh rotate switch upwards withershins
🔙 back arrow arrow words return above leftwards
🔚 end arrow words arrow above leftwards
🔛 on arrow arrow words above exclamation left mark on! right
🔜 soon arrow arrow words above rightwards
🔝 top arrow words blue-square above up upwards
🛐 place of worship religion church temple prayer building religious
⚛️ atom symbol science physics chemistry atheist
🕉️ om hinduism buddhism sikhism jainism aumkara hindu omkara pranava religion symbol
✡️ star of david judaism jew jewish magen religion
☸️ wheel of dharma hinduism buddhism sikhism jainism buddhist helm religion
☯️ yin yang balance religion tao taoist
✝️ latin cross christianity christian religion
☦️ orthodox cross suppedaneum religion christian
☪️ star and crescent islam muslim religion
☮️ peace symbol hippie sign
🕎 menorah hanukkah candles jewish branches candelabrum candlestick chanukiah nine religion
🔯 dotted six pointed star purple-square religion jewish hexagram dot fortune middle
♈ aries sign purple-square zodiac astrology ram
♉ taurus purple-square sign zodiac astrology bull ox
♊ gemini sign zodiac purple-square astrology twins
♋ cancer sign zodiac purple-square astrology crab
♌ leo sign purple-square zodiac astrology lion
♍ virgo sign zodiac purple-square astrology maiden virgin
♎ libra sign purple-square zodiac astrology balance justice scales
♏ scorpio sign zodiac purple-square astrology scorpion scorpius
♐ sagittarius sign zodiac purple-square astrology archer
♑ capricorn sign zodiac purple-square astrology goat
♒ aquarius sign purple-square zodiac astrology bearer water
♓ pisces purple-square sign zodiac astrology fish
⛎ ophiuchus sign purple-square constellation astrology bearer serpent snake zodiac
🔀 shuffle tracks button blue-square shuffle music random arrow arrows crossed rightwards symbol twisted
🔁 repeat button loop record arrow arrows circle clockwise leftwards open retweet rightwards symbol
🔂 repeat single button blue-square loop arrow arrows circle circled clockwise leftwards number once one open overlay rightwards symbol track
▶️ play button blue-square right direction play arrow black forward pointing right triangle triangle
⏩ fast forward button blue-square play speed continue arrow black double pointing right symbol triangle
⏭️ next track button forward next blue-square arrow bar black double pointing right scene skip symbol triangle vertical
⏯️ play or pause button blue-square play pause arrow bar black double play/pause pointing right symbol triangle vertical
◀️ reverse button blue-square left direction arrow backward black pointing triangle
⏪ fast reverse button play blue-square arrow black double left pointing rewind symbol triangle
⏮️ last track button backward arrow bar black double left pointing previous scene skip symbol triangle vertical
🔼 upwards button blue-square triangle direction point forward top arrow pointing red small up
⏫ fast up button blue-square direction top arrow black double pointing triangle
🔽 downwards button blue-square direction bottom arrow down pointing red small triangle
⏬ fast down button blue-square direction bottom arrow black double pointing triangle
⏸️ pause button pause blue-square bar double symbol vertical
⏹️ stop button blue-square black for square symbol
⏺️ record button blue-square black circle for symbol
⏏️ eject button blue-square symbol
🎦 cinema blue-square record film movie curtain stage theater activity camera entertainment movies screen symbol
🔅 dim button sun afternoon warm summer brightness decrease low symbol
🔆 bright button sun light brightness high increase symbol
📶 antenna bars blue-square reception phone internet connection wifi bluetooth bars bar cell cellular communication mobile signal stairs strength telephone
📳 vibration mode orange-square phone cell communication heart mobile silent telephone
📴 mobile phone off mute orange-square silence quiet cell communication telephone
♀️ female sign woman women lady girl symbol venus
♂️ male sign man boy men mars symbol
⚕️ medical symbol health hospital aesculapius asclepius asklepios care doctor medicine rod snake staff
♾️ infinity forever paper permanent sign unbounded universal
♻️ recycling symbol arrow environment garbage trash black green logo recycle universal
⚜️ fleur de lis decorative scout new orleans saints scouts
🔱 trident emblem weapon spear anchor pitchfork ship tool
📛 name badge fire forbid tag tofu
🔰 japanese symbol for beginner badge shield chevron green leaf mark shoshinsha tool yellow
⭕ hollow red circle circle round correct heavy large mark o
✅ check mark button green-square ok agree vote election answer tick green heavy symbol white
☑️ check box with check ok agree confirm black-square vote election yes tick ballot checkbox mark
✔️ check mark ok nike answer yes tick heavy
✖️ multiplication sign math calculation cancel heavy multiply symbol x
❌ cross mark no delete remove cancel red multiplication multiply x
❎ cross mark button x green-square no deny negative square squared
➕ plus sign math calculation addition more increase heavy symbol
➖ minus sign math calculation subtract less heavy symbol
➗ division sign divide math calculation heavy symbol
➰ curly loop scribble draw shape squiggle curl curling
➿ double curly loop tape cassette curl curling voicemail
〽️ part alternation mark graph presentation stats business economics bad m mcdonald’s
✳️ eight spoked asterisk star sparkle green-square
✴️ eight pointed star orange-square shape polygon black orange
❇️ sparkle stars green-square awesome good fireworks
‼️ double exclamation mark exclamation surprise bangbang punctuation red
⁉️ exclamation question mark wat punctuation surprise interrobang red
❓ question mark doubt confused black ornament punctuation red
❔ white question mark doubts gray huh confused grey ornament outlined punctuation
❕ white exclamation mark surprise punctuation gray wow warning grey ornament outlined
❗ exclamation mark heavy exclamation mark danger surprise punctuation wow warning bang red symbol
〰️ wavy dash draw line moustache mustache squiggle scribble punctuation wave
©️ copyright ip license circle law legal c sign
®️ registered alphabet circle r sign
™️ trade mark trademark brand law legal sign tm
#️⃣ keycap  symbol blue-square twitter hash hashtag key number octothorpe pound sign
*️⃣ keycap  star keycap asterisk
0️⃣ keycap 0 0 numbers blue-square null zero digit
1️⃣ keycap 1 blue-square numbers 1 one digit
2️⃣ keycap 2 numbers 2 prime blue-square two digit
3️⃣ keycap 3 3 numbers prime blue-square three digit
4️⃣ keycap 4 4 numbers blue-square four digit
5️⃣ keycap 5 5 numbers blue-square prime five digit
6️⃣ keycap 6 6 numbers blue-square six digit
7️⃣ keycap 7 7 numbers blue-square prime seven digit
8️⃣ keycap 8 8 blue-square numbers eight digit
9️⃣ keycap 9 blue-square numbers 9 nine digit
🔟 keycap 10 numbers 10 blue-square ten number
🔠 input latin uppercase alphabet words letters uppercase blue-square abcd capital for symbol
🔡 input latin lowercase blue-square letters lowercase alphabet abcd for small symbol
🔢 input numbers numbers blue-square 1234 1 2 3 4 for numeric symbol
🔣 input symbols blue-square music note ampersand percent glyphs characters for symbol symbol input
🔤 input latin letters blue-square alphabet abc for symbol
🅰️ a button red-square alphabet letter blood capital latin negative squared type
🆎 ab button red-square alphabet blood negative squared type
🅱️ b button red-square alphabet letter blood capital latin negative squared type
🆑 cl button alphabet words red-square clear sign squared
🆒 cool button words blue-square sign square squared
🆓 free button blue-square words sign squared
ℹ️ information blue-square alphabet letter i info lowercase source tourist
🆔 id button purple-square words identification identity sign squared
Ⓜ️ circled m alphabet blue-circle letter capital circle latin metro
🆕 new button blue-square words start fresh sign squared
🆖 ng button blue-square words shape icon blooper good no sign squared
🅾️ o button alphabet red-square letter blood capital latin negative o2 squared type
🆗 ok button good agree yes blue-square okay sign square squared
🅿️ p button cars blue-square alphabet letter capital latin negative parking sign squared
🆘 sos button help red-square words emergency 911 distress sign signal squared
🆙 up button blue-square above high exclamation level mark sign squared up!
🆚 vs button words orange-square squared versus
🈁 japanese here button blue-square here katakana japanese destination koko meaning sign squared word “here”
🈂️ japanese service charge button japanese blue-square katakana charge” meaning or sa sign squared “service “service”
🈷️ japanese monthly amount button chinese month moon japanese orange-square kanji amount” cjk ideograph meaning radical sign squared u6708 unified “monthly
🈶 japanese not free of charge button orange-square chinese have kanji charge” cjk exist ideograph meaning own sign squared u6709 unified “not
🈯 japanese reserved button chinese point green-square kanji cjk finger ideograph meaning sign squared u6307 unified “reserved”
🉐 japanese bargain button chinese kanji obtain get circle acquire advantage circled ideograph meaning sign “bargain”
🈹 japanese discount button cut divide chinese kanji pink-square bargain cjk ideograph meaning sale sign squared u5272 unified “discount”
🈚 japanese free of charge button nothing chinese kanji japanese orange-square charge” cjk ideograph lacking meaning negation sign squared u7121 unified “free
🈲 japanese prohibited button kanji japanese chinese forbidden limit restricted red-square cjk forbid ideograph meaning prohibit sign squared u7981 unified “prohibited”
🉑 japanese acceptable button ok good chinese kanji agree yes orange-circle accept circled ideograph meaning sign “acceptable”
🈸 japanese application button chinese japanese kanji orange-square apply cjk form ideograph meaning monkey request sign squared u7533 unified “application”
🈴 japanese passing grade button japanese chinese join kanji red-square agreement cjk grade” ideograph meaning sign squared together u5408 unified “passing
🈳 japanese vacancy button kanji japanese chinese empty sky blue-square 7a7a available cjk ideograph meaning sign squared u7a7a unified “vacancy”
㊗️ japanese congratulations button chinese kanji japanese red-circle circled congratulate congratulation ideograph meaning sign “congratulations”
㊙️ japanese secret button privacy chinese sshh kanji red-circle circled ideograph meaning sign “secret”
🈺 japanese open for business button japanese opening hours orange-square 55b6 business” chinese cjk ideograph meaning operating sign squared u55b6 unified work “open
🈵 japanese no vacancy button full chinese japanese red-square kanji 6e80 cjk fullness ideograph meaning sign squared u6e80 unified vacancy” “full; “no
🔴 red circle shape error danger geometric large
🟠 orange circle round geometric large
🟡 yellow circle round geometric large
🟢 green circle round geometric large
🔵 blue circle shape icon button geometric large
🟣 purple circle round geometric large
🟤 brown circle round geometric large
⚫ black circle shape button round geometric medium
⚪ white circle shape round geometric medium
🟥 red square card geometric large
🟧 orange square geometric large
🟨 yellow square card geometric large
🟩 green square geometric large
🟦 blue square geometric large
🟪 purple square geometric large
🟫 brown square geometric large
⬛ black large square shape icon button geometric
⬜ white large square shape icon stone button geometric
◼️ black medium square shape button icon geometric
◻️ white medium square shape stone icon geometric
◾ black medium small square icon shape button geometric
◽ white medium small square shape stone icon button geometric
▪️ black small square shape icon geometric
▫️ white small square shape icon geometric
🔶 large orange diamond shape jewel gem geometric
🔷 large blue diamond shape jewel gem geometric
🔸 small orange diamond shape jewel gem geometric
🔹 small blue diamond shape jewel gem geometric
🔺 red triangle pointed up shape direction up top geometric pointing small
🔻 red triangle pointed down shape direction bottom geometric pointing small
💠 diamond with a dot jewel blue gem crystal fancy comic cuteness flower geometric inside kawaii shape
🔘 radio button input old music circle geometric
🔳 white square button shape input geometric outlined
🔲 black square button shape input frame geometric
🏁 chequered flag contest finishline race gokart checkered finish girl grid milestone racing
🚩 triangular flag mark milestone place pole post red
🎌 crossed flags japanese nation country border activity celebration cross flag two
🏴 black flag pirate waving
🏳️ white flag losing loser lost surrender give up fail waving
🏳️‍🌈 rainbow flag flag rainbow pride gay lgbt queer homosexual lesbian bisexual
🏴‍☠️ pirate flag skull crossbones flag banner jolly plunder roger treasure
🇦🇨 flag ascension island
🇦🇩 flag andorra ad flag nation country banner andorra andorran
🇦🇪 flag united arab emirates united arab emirates flag nation country banner united arab emirates emirati uae
🇦🇫 flag afghanistan af flag nation country banner afghanistan afghan
🇦🇬 flag antigua barbuda antigua barbuda flag nation country banner antigua barbuda
🇦🇮 flag anguilla ai flag nation country banner anguilla anguillan
🇦🇱 flag albania al flag nation country banner albania albanian
🇦🇲 flag armenia am flag nation country banner armenia armenian
🇦🇴 flag angola ao flag nation country banner angola angolan
🇦🇶 flag antarctica aq flag nation country banner antarctica antarctic
🇦🇷 flag argentina ar flag nation country banner argentina argentinian
🇦🇸 flag american samoa american ws flag nation country banner american samoa samoan
🇦🇹 flag austria at flag nation country banner austria austrian
🇦🇺 flag australia au flag nation country banner australia aussie australian heard mcdonald
🇦🇼 flag aruba aw flag nation country banner aruba aruban
🇦🇽 flag aland islands Åland islands flag nation country banner aland islands
🇦🇿 flag azerbaijan az flag nation country banner azerbaijan azerbaijani
🇧🇦 flag bosnia herzegovina bosnia herzegovina flag nation country banner bosnia herzegovina
🇧🇧 flag barbados bb flag nation country banner barbados bajan barbadian
🇧🇩 flag bangladesh bd flag nation country banner bangladesh bangladeshi
🇧🇪 flag belgium be flag nation country banner belgium belgian
🇧🇫 flag burkina faso burkina faso flag nation country banner burkina faso burkinabe
🇧🇬 flag bulgaria bg flag nation country banner bulgaria bulgarian
🇧🇭 flag bahrain bh flag nation country banner bahrain bahrainian bahrani
🇧🇮 flag burundi bi flag nation country banner burundi burundian
🇧🇯 flag benin bj flag nation country banner benin beninese
🇧🇱 flag st barthelemy saint barthélemy flag nation country banner st barthelemy st.
🇧🇲 flag bermuda bm flag nation country banner bermuda bermudan flag
🇧🇳 flag brunei bn darussalam flag nation country banner brunei bruneian
🇧🇴 flag bolivia bo flag nation country banner bolivia bolivian
🇧🇶 flag caribbean netherlands bonaire flag nation country banner caribbean netherlands eustatius saba sint
🇧🇷 flag brazil br flag nation country banner brazil brasil brazilian for
🇧🇸 flag bahamas bs flag nation country banner bahamas bahamian
🇧🇹 flag bhutan bt flag nation country banner bhutan bhutanese
🇧🇻 flag bouvet island norway
🇧🇼 flag botswana bw flag nation country banner botswana batswana
🇧🇾 flag belarus by flag nation country banner belarus belarusian
🇧🇿 flag belize bz flag nation country banner belize belizean
🇨🇦 flag canada ca flag nation country banner canada canadian
🇨🇨 flag cocos islands cocos keeling islands flag nation country banner cocos islands island
🇨🇩 flag congo kinshasa congo democratic republic flag nation country banner congo kinshasa drc
🇨🇫 flag central african republic central african republic flag nation country banner central african republic
🇨🇬 flag congo brazzaville congo flag nation country banner congo brazzaville republic
🇨🇭 flag switzerland ch flag nation country banner switzerland cross red swiss
🇨🇮 flag cote d ivoire ivory coast flag nation country banner cote d ivoire côte divoire d’ivoire
🇨🇰 flag cook islands cook islands flag nation country banner cook islands island islander
🇨🇱 flag chile flag nation country banner chile chilean
🇨🇲 flag cameroon cm flag nation country banner cameroon cameroonian
🇨🇳 flag china china chinese prc flag country nation banner cn indicator letters regional symbol
🇨🇴 flag colombia co flag nation country banner colombia colombian
🇨🇵 flag clipperton island
🇨🇷 flag costa rica costa rica flag nation country banner costa rica rican
🇨🇺 flag cuba cu flag nation country banner cuba cuban
🇨🇻 flag cape verde cabo verde flag nation country banner cape verde verdian
🇨🇼 flag curacao curaçao flag nation country banner curacao antilles curaçaoan
🇨🇽 flag christmas island christmas island flag nation country banner christmas island
🇨🇾 flag cyprus cy flag nation country banner cyprus cypriot
🇨🇿 flag czechia cz flag nation country banner czechia czech republic
🇩🇪 flag germany german nation flag country banner germany de deutsch indicator letters regional symbol
🇩🇬 flag diego garcia
🇩🇯 flag djibouti dj flag nation country banner djibouti djiboutian
🇩🇰 flag denmark dk flag nation country banner denmark danish
🇩🇲 flag dominica dm flag nation country banner dominica
🇩🇴 flag dominican republic dominican republic flag nation country banner dominican republic dom rep
🇩🇿 flag algeria dz flag nation country banner algeria algerian
🇪🇦 flag ceuta melilla
🇪🇨 flag ecuador ec flag nation country banner ecuador ecuadorian
🇪🇪 flag estonia ee flag nation country banner estonia estonian
🇪🇬 flag egypt eg flag nation country banner egypt egyptian
🇪🇭 flag western sahara western sahara flag nation country banner western sahara saharan west
🇪🇷 flag eritrea er flag nation country banner eritrea eritrean
🇪🇸 flag spain spain flag nation country banner ceuta es indicator letters melilla regional spanish symbol
🇪🇹 flag ethiopia et flag nation country banner ethiopia ethiopian
🇪🇺 flag european union european union flag banner eu
🇫🇮 flag finland fi flag nation country banner finland finnish
🇫🇯 flag fiji fj flag nation country banner fiji fijian
🇫🇰 flag falkland islands falkland islands malvinas flag nation country banner falkland islands falklander falklands island islas
🇫🇲 flag micronesia micronesia federated states flag nation country banner micronesian
🇫🇴 flag faroe islands faroe islands flag nation country banner faroe islands island islander
🇫🇷 flag france banner flag nation france french country clipperton fr indicator island letters martin regional saint st. symbol
🇬🇦 flag gabon ga flag nation country banner gabon gabonese
🇬🇧 flag united kingdom united kingdom great britain northern ireland flag nation country banner british UK english england union jack united kingdom cornwall gb scotland wales
🇬🇩 flag grenada gd flag nation country banner grenada grenadian
🇬🇪 flag georgia ge flag nation country banner georgia georgian
🇬🇫 flag french guiana french guiana flag nation country banner french guiana guinean
🇬🇬 flag guernsey gg flag nation country banner guernsey
🇬🇭 flag ghana gh flag nation country banner ghana ghanaian
🇬🇮 flag gibraltar gi flag nation country banner gibraltar gibraltarian
🇬🇱 flag greenland gl flag nation country banner greenland greenlandic
🇬🇲 flag gambia gm flag nation country banner gambia gambian flag
🇬🇳 flag guinea gn flag nation country banner guinea guinean
🇬🇵 flag guadeloupe gp flag nation country banner guadeloupe guadeloupean
🇬🇶 flag equatorial guinea equatorial gn flag nation country banner equatorial guinea equatoguinean guinean
🇬🇷 flag greece gr flag nation country banner greece greek
🇬🇸 flag south georgia south sandwich islands south georgia sandwich islands flag nation country banner south georgia south sandwich islands island
🇬🇹 flag guatemala gt flag nation country banner guatemala guatemalan
🇬🇺 flag guam gu flag nation country banner guam chamorro guamanian
🇬🇼 flag guinea bissau gw bissau flag nation country banner guinea bissau
🇬🇾 flag guyana gy flag nation country banner guyana guyanese
🇭🇰 flag hong kong sar china hong kong flag nation country banner hong kong sar china
🇭🇲 flag heard mcdonald islands
🇭🇳 flag honduras hn flag nation country banner honduras honduran
🇭🇷 flag croatia hr flag nation country banner croatia croatian
🇭🇹 flag haiti ht flag nation country banner haiti haitian
🇭🇺 flag hungary hu flag nation country banner hungary hungarian
🇮🇨 flag canary islands canary islands flag nation country banner canary islands island
🇮🇩 flag indonesia flag nation country banner indonesia indonesian
🇮🇪 flag ireland ie flag nation country banner ireland irish flag
🇮🇱 flag israel il flag nation country banner israel israeli
🇮🇲 flag isle of man isle man flag nation country banner isle of man manx
🇮🇳 flag india in flag nation country banner india indian
🇮🇴 flag british indian ocean territory british indian ocean territory flag nation country banner british indian ocean territory chagos diego garcia island
🇮🇶 flag iraq iq flag nation country banner iraq iraqi
🇮🇷 flag iran iran islamic republic flag nation country banner iranian flag
🇮🇸 flag iceland is flag nation country banner iceland icelandic
🇮🇹 flag italy italy flag nation country banner indicator italian letters regional symbol
🇯🇪 flag jersey je flag nation country banner jersey
🇯🇲 flag jamaica jm flag nation country banner jamaica jamaican flag
🇯🇴 flag jordan jo flag nation country banner jordan jordanian
🇯🇵 flag japan japanese nation flag country banner japan jp ja indicator letters regional symbol
🇰🇪 flag kenya ke flag nation country banner kenya kenyan
🇰🇬 flag kyrgyzstan kg flag nation country banner kyrgyzstan kyrgyzstani
🇰🇭 flag cambodia kh flag nation country banner cambodia cambodian
🇰🇮 flag kiribati ki flag nation country banner kiribati i
🇰🇲 flag comoros km flag nation country banner comoros comoran
🇰🇳 flag st kitts nevis saint kitts nevis flag nation country banner st kitts nevis st.
🇰🇵 flag north korea north korea nation flag country banner north korea korean
🇰🇷 flag south korea south korea nation flag country banner south korea indicator korean kr letters regional symbol
🇰🇼 flag kuwait kw flag nation country banner kuwait kuwaiti
🇰🇾 flag cayman islands cayman islands flag nation country banner cayman islands caymanian island
🇰🇿 flag kazakhstan kz flag nation country banner kazakhstan kazakh kazakhstani
🇱🇦 flag laos lao democratic republic flag nation country banner laos laotian
🇱🇧 flag lebanon lb flag nation country banner lebanon lebanese
🇱🇨 flag st lucia saint lucia flag nation country banner st lucia st.
🇱🇮 flag liechtenstein li flag nation country banner liechtenstein liechtensteiner
🇱🇰 flag sri lanka sri lanka flag nation country banner sri lanka lankan
🇱🇷 flag liberia lr flag nation country banner liberia liberian
🇱🇸 flag lesotho ls flag nation country banner lesotho basotho
🇱🇹 flag lithuania lt flag nation country banner lithuania lithuanian
🇱🇺 flag luxembourg lu flag nation country banner luxembourg luxembourger
🇱🇻 flag latvia lv flag nation country banner latvia latvian
🇱🇾 flag libya ly flag nation country banner libya libyan
🇲🇦 flag morocco ma flag nation country banner morocco moroccan
🇲🇨 flag monaco mc flag nation country banner monaco monégasque
🇲🇩 flag moldova moldova republic flag nation country banner moldovan
🇲🇪 flag montenegro me flag nation country banner montenegro montenegrin
🇲🇫 flag st martin st.
🇲🇬 flag madagascar mg flag nation country banner madagascar madagascan
🇲🇭 flag marshall islands marshall islands flag nation country banner marshall islands island marshallese
🇲🇰 flag north macedonia macedonia flag nation country banner north macedonia macedonian
🇲🇱 flag mali ml flag nation country banner mali malian
🇲🇲 flag myanmar mm flag nation country banner myanmar burma burmese for myanmarese flag
🇲🇳 flag mongolia mn flag nation country banner mongolia mongolian
🇲🇴 flag macao sar china macao flag nation country banner macao sar china macanese flag macau
🇲🇵 flag northern mariana islands northern mariana islands flag nation country banner northern mariana islands island micronesian north
🇲🇶 flag martinique mq flag nation country banner martinique martiniquais flag of martinique snake
🇲🇷 flag mauritania mr flag nation country banner mauritania mauritanian
🇲🇸 flag montserrat ms flag nation country banner montserrat montserratian
🇲🇹 flag malta mt flag nation country banner malta maltese
🇲🇺 flag mauritius mu flag nation country banner mauritius mauritian
🇲🇻 flag maldives mv flag nation country banner maldives maldivian
🇲🇼 flag malawi mw flag nation country banner malawi malawian flag
🇲🇽 flag mexico mx flag nation country banner mexico mexican
🇲🇾 flag malaysia my flag nation country banner malaysia malaysian
🇲🇿 flag mozambique mz flag nation country banner mozambique mozambican
🇳🇦 flag namibia na flag nation country banner namibia namibian
🇳🇨 flag new caledonia new caledonia flag nation country banner new caledonia caledonian
🇳🇪 flag niger ne flag nation country banner niger nigerien flag
🇳🇫 flag norfolk island norfolk island flag nation country banner norfolk island
🇳🇬 flag nigeria flag nation country banner nigeria nigerian
🇳🇮 flag nicaragua ni flag nation country banner nicaragua nicaraguan
🇳🇱 flag netherlands nl flag nation country banner netherlands dutch
🇳🇴 flag norway no flag nation country banner norway bouvet jan mayen norwegian svalbard
🇳🇵 flag nepal np flag nation country banner nepal nepalese
🇳🇷 flag nauru nr flag nation country banner nauru nauruan
🇳🇺 flag niue nu flag nation country banner niue niuean
🇳🇿 flag new zealand new zealand flag nation country banner new zealand kiwi
🇴🇲 flag oman om symbol flag nation country banner oman omani
🇵🇦 flag panama pa flag nation country banner panama panamanian
🇵🇪 flag peru pe flag nation country banner peru peruvian
🇵🇫 flag french polynesia french polynesia flag nation country banner french polynesia polynesian
🇵🇬 flag papua new guinea papua new guinea flag nation country banner papua new guinea guinean png
🇵🇭 flag philippines ph flag nation country banner philippines
🇵🇰 flag pakistan pk flag nation country banner pakistan pakistani
🇵🇱 flag poland pl flag nation country banner poland polish
🇵🇲 flag st pierre miquelon saint pierre miquelon flag nation country banner st pierre miquelon st.
🇵🇳 flag pitcairn islands pitcairn flag nation country banner pitcairn islands island
🇵🇷 flag puerto rico puerto rico flag nation country banner puerto rico rican
🇵🇸 flag palestinian territories palestine palestinian territories flag nation country banner palestinian territories
🇵🇹 flag portugal pt flag nation country banner portugal portugese
🇵🇼 flag palau pw flag nation country banner palau palauan
🇵🇾 flag paraguay py flag nation country banner paraguay paraguayan
🇶🇦 flag qatar qa flag nation country banner qatar qatari
🇷🇪 flag reunion réunion flag nation country banner reunion réunionnais
🇷🇴 flag romania ro flag nation country banner romania romanian
🇷🇸 flag serbia rs flag nation country banner serbia serbian flag
🇷🇺 flag russia russian federation flag nation country banner russia indicator letters regional ru symbol
🇷🇼 flag rwanda rw flag nation country banner rwanda rwandan
🇸🇦 flag saudi arabia flag nation country banner saudi arabia arabian flag
🇸🇧 flag solomon islands solomon islands flag nation country banner solomon islands island islander flag
🇸🇨 flag seychelles sc flag nation country banner seychelles seychellois flag
🇸🇩 flag sudan sd flag nation country banner sudan sudanese
🇸🇪 flag sweden se flag nation country banner sweden swedish
🇸🇬 flag singapore sg flag nation country banner singapore singaporean
🇸🇭 flag st helena saint helena ascension tristan cunha flag nation country banner st helena st.
🇸🇮 flag slovenia si flag nation country banner slovenia slovenian
🇸🇯 flag svalbard jan mayen
🇸🇰 flag slovakia sk flag nation country banner slovakia slovakian slovak flag
🇸🇱 flag sierra leone sierra leone flag nation country banner sierra leone leonean
🇸🇲 flag san marino san marino flag nation country banner san marino sammarinese
🇸🇳 flag senegal sn flag nation country banner senegal sengalese
🇸🇴 flag somalia so flag nation country banner somalia somalian flag
🇸🇷 flag suriname sr flag nation country banner suriname surinamer
🇸🇸 flag south sudan south sd flag nation country banner south sudan sudanese flag
🇸🇹 flag sao tome principe sao tome principe flag nation country banner sao tome principe príncipe são tomé
🇸🇻 flag el salvador el salvador flag nation country banner el salvador salvadoran
🇸🇽 flag sint maarten sint maarten dutch flag nation country banner sint maarten
🇸🇾 flag syria syrian arab republic flag nation country banner syria
🇸🇿 flag eswatini sz flag nation country banner eswatini swaziland
🇹🇦 flag tristan da cunha
🇹🇨 flag turks caicos islands turks caicos islands flag nation country banner turks caicos islands island
🇹🇩 flag chad td flag nation country banner chad chadian
🇹🇫 flag french southern territories french southern territories flag nation country banner french southern territories antarctic lands
🇹🇬 flag togo tg flag nation country banner togo togolese
🇹🇭 flag thailand th flag nation country banner thailand thai
🇹🇯 flag tajikistan tj flag nation country banner tajikistan tajik
🇹🇰 flag tokelau tk flag nation country banner tokelau tokelauan
🇹🇱 flag timor leste timor leste flag nation country banner timor leste east leste flag timorese
🇹🇲 flag turkmenistan flag nation country banner turkmenistan turkmen
🇹🇳 flag tunisia tn flag nation country banner tunisia tunisian
🇹🇴 flag tonga to flag nation country banner tonga tongan flag
🇹🇷 flag turkey turkey flag nation country banner tr turkish flag türkiye
🇹🇹 flag trinidad tobago trinidad tobago flag nation country banner trinidad tobago
🇹🇻 flag tuvalu flag nation country banner tuvalu tuvaluan
🇹🇼 flag taiwan tw flag nation country banner taiwan china taiwanese
🇹🇿 flag tanzania tanzania united republic flag nation country banner tanzanian
🇺🇦 flag ukraine ua flag nation country banner ukraine ukrainian
🇺🇬 flag uganda ug flag nation country banner uganda ugandan flag
🇺🇲 flag u s outlying islands u.s. us
🇺🇳 flag united nations un flag banner
🇺🇸 flag united states united states america flag nation country banner united states american indicator islands letters outlying regional symbol us usa
🇺🇾 flag uruguay uy flag nation country banner uruguay uruguayan
🇺🇿 flag uzbekistan uz flag nation country banner uzbekistan uzbek uzbekistani
🇻🇦 flag vatican city vatican city flag nation country banner vatican city vanticanien
🇻🇨 flag st vincent grenadines saint vincent grenadines flag nation country banner st vincent grenadines st.
🇻🇪 flag venezuela ve bolivarian republic flag nation country banner venezuela venezuelan
🇻🇬 flag british virgin islands british virgin islands bvi flag nation country banner british virgin islands island islander
🇻🇮 flag u s virgin islands virgin islands us flag nation country banner u s virgin islands america island islander states u.s. united usa
🇻🇳 flag vietnam viet nam flag nation country banner vietnam vietnamese
🇻🇺 flag vanuatu vu flag nation country banner vanuatu ni vanuatu flag
🇼🇫 flag wallis futuna wallis futuna flag nation country banner wallis futuna
🇼🇸 flag samoa ws flag nation country banner samoa samoan flag
🇽🇰 flag kosovo xk flag nation country banner kosovo kosovar
🇾🇪 flag yemen ye flag nation country banner yemen yemeni flag
🇾🇹 flag mayotte yt flag nation country banner mayotte
🇿🇦 flag south africa south africa flag nation country banner south africa african flag
🇿🇲 flag zambia zm flag nation country banner zambia zambian
🇿🇼 flag zimbabwe zw flag nation country banner zimbabwe zim zimbabwean flag
🏴󠁧󠁢󠁥󠁮󠁧󠁿 flag england flag english cross george's st
🏴󠁧󠁢󠁳󠁣󠁴󠁿 flag scotland flag scottish andrew's cross saltire st
🏴󠁧󠁢󠁷󠁬󠁳󠁿 flag wales flag welsh baner cymru ddraig dragon goch red y
🥲 smiling face with tear sad cry pretend grateful happy proud relieved smile touched
🥸 disguised face pretent brows glasses moustache disguise incognito nose
🤌 pinched fingers size tiny small che finger gesture hand interrogation ma purse sarcastic vuoi
🫀 anatomical heart health heartbeat cardiology organ pulse
🫁 lungs breathe breath exhalation inhalation organ respiration
🥷 ninja ninjutsu skills japanese fighter hidden stealth
🤵‍♂️ man in tuxedo formal fashion groom male men person suit wedding
🤵‍♀️ woman in tuxedo formal fashion female wedding women
👰‍♂️ man with veil wedding marriage bride male men
👰‍♀️ woman with veil wedding marriage bride female women
👩‍🍼 woman feeding baby birth food bottle child female infant milk nursing women
👨‍🍼 man feeding baby birth food bottle child infant male men milk nursing
🧑‍🍼 person feeding baby birth food bottle child infant milk nursing
🧑‍🎄 mx claus christmas activity celebration mx. santa
🫂 people hugging care goodbye hello hug thanks
🐈‍⬛ black cat superstition luck halloween pet unlucky
🦬 bison ox buffalo herd wisent
🦣 mammoth elephant tusks extinct extinction large tusk woolly
🦫 beaver animal rodent dam
🐻‍❄️ polar bear animal arctic face white
🦤 dodo animal bird extinct extinction large mauritius obsolete
🪶 feather bird fly flight light plumage
🦭 seal animal creature sea lion
🪲 beetle insect bug
🪳 cockroach insect pests pest roach
🪰 fly insect disease maggot pest rotting
🪱 worm animal annelid earthworm parasite
🪴 potted plant greenery house boring grow houseplant nurturing useless
🫐 blueberries fruit berry bilberry blue blueberry
🫒 olive fruit food olives
🫑 bell pepper fruit plant capsicum vegetable
🫓 flatbread flour food bakery arepa bread flat lavash naan pita
🫔 tamale food masa mexican tamal wrapped
🫕 fondue cheese pot food chocolate melted swiss
🫖 teapot drink hot kettle pot tea
🧋 bubble tea taiwan boba milk tea straw momi pearl tapioca
🪨 rock stone boulder construction heavy solid
🪵 wood nature timber trunk construction log lumber
🛖 hut house structure roundhouse yurt
🛻 pickup truck car transportation vehicle
🛼 roller skate footwear sports derby inline
🪄 magic wand supernature power witch wizard
🪅 pinata mexico candy celebration party piñata
🪆 nesting dolls matryoshka toy doll russia russian
🪡 sewing needle stitches embroidery sutures tailoring
🪢 knot rope scout tangled tie twine twist
🩴 thong sandal footwear summer beach flip flops jandals sandals thongs zōri
🪖 military helmet army protection soldier warrior
🪗 accordion music accordian box concertina squeeze
🪘 long drum music beat conga djembe rhythm
🪙 coin money currency gold metal silver treasure
🪃 boomerang weapon australia rebound repercussion
🪚 carpentry saw cut chop carpenter hand lumber tool
🪛 screwdriver tools screw tool
🪝 hook tools catch crook curve ensnare fishing point selling tool
🪜 ladder tools climb rung step tool
🛗 elevator lift accessibility hoist
🪞 mirror reflection reflector speculum
🪟 window scenery air frame fresh glass opening transparent view
🪠 plunger toilet cup force plumber suction
🪤 mouse trap cheese bait mousetrap rodent snare
🪣 bucket water container cask pail vat
🪥 toothbrush hygiene dental bathroom brush clean teeth
🪦 headstone death rip grave cemetery graveyard halloween tombstone
🪧 placard announcement demonstration lawn picket post protest sign
⚧️ transgender symbol transgender lgbtq female lgbt male pride sign stroke
🏳️‍⚧️ transgender flag transgender flag pride lgbtq blue lgbt light pink trans white
😶‍🌫️ face in clouds shower steam dream absentminded brain fog forgetful haze head impractical unrealistic
😮‍💨 face exhaling relieve relief tired sigh exhale gasp groan whisper whistle
😵‍💫 face with spiral eyes sick ill confused nauseous nausea dizzy hypnotized trouble whoa
❤️‍🔥 heart on fire passionate enthusiastic burn love lust sacred
❤️‍🩹 mending heart broken heart bandage wounded bandaged healing healthier improving recovering recuperating unbroken well
🧔‍♂️ man beard facial hair bearded bewhiskered male men
🧔‍♀️ woman beard facial hair bearded bewhiskered female women
🫠 melting face hot heat disappear dissolve dread liquid melt sarcasm
🫢 face with open eyes and hand over mouth silence secret shock surprise amazement awe disbelief embarrass gasp scared
🫣 face with peeking eye scared frightening embarrassing shy captivated peep stare
🫡 saluting face respect salute ok sunny troops yes
🫥 dotted line face invisible lonely isolation depression depressed disappear hide introvert
🫤 face with diagonal mouth skeptic confuse frustrated indifferent confused disappointed meh skeptical unsure
🥹 face holding back tears touched gratitude cry angry proud resist sad
🫱 rightwards hand palm offer right rightward
🫲 leftwards hand palm offer left leftward
🫳 palm down hand palm drop dismiss shoo
🫴 palm up hand lift offer demand beckon catch come
🫰 hand with index finger and thumb crossed heart love money expensive snap
🫵 index pointing at the viewer you recruit point
🫶 heart hands love appreciation support
🫦 biting lip flirt sexy pain worry anxious fear flirting nervous uncomfortable worried
🫅 person with crown royalty power monarch noble regal
🫃 pregnant man baby belly bloated full
🫄 pregnant person baby belly bloated full
🧌 troll mystical monster fairy fantasy tale shrek
🪸 coral ocean sea reef
🪷 lotus flower calm meditation buddhism hinduism india purity vietnam
🪹 empty nest bird nesting
🪺 nest with eggs bird nesting
🫘 beans food kidney legume
🫗 pouring liquid cup water drink empty glass spill
🫙 jar container sauce condiment empty store
🛝 playground slide fun park amusement play
🛞 wheel car transport circle tire turn
🛟 ring buoy life saver life preserver float rescue safety
🪬 hamsa religion protection amulet fatima hand mary miriam
🪩 mirror ball disco dance party glitter
🪫 low battery drained dead electronic energy no red
🩼 crutch accessibility assist aid cane disability hurt mobility stick
🩻 x-ray skeleton medicine bones doctor medical ray x
🫧 bubbles soap fun carbonation sparkling burp clean underwater
🪪 identification card document credentials id license security
🟰 heavy equals sign math equality
🫨 shaking face dizzy shock blurry earthquake
🩷 pink heart valentines
🩵 light blue heart ice baby blue
🩶 grey heart silver monochrome
🫷 leftwards pushing hand highfive pressing stop
🫸 rightwards pushing hand highfive pressing stop
🫎 moose canada sweden sven cool
🫏 donkey eeyore mule
🪽 wing angel birds flying fly
🐦‍⬛ black bird crow
🪿 goose silly jemima goosebumps honk
🪼 jellyfish sting tentacles
🪻 hyacinth flower lavender
🫚 ginger root spice yellow cooking gingerbread
🫛 pea pod cozy green
🪭 folding hand fan flamenco hot sensu
🪮 hair pick afro comb
🪇 maracas music instrument percussion shaker
🪈 flute bamboo music instrument pied piper recorder
🪯 khanda Sikhism religion
🛜 wireless wifi internet contactless signal
🙂‍↔️ head shaking horizontally disapprove indiffernt left
🙂‍↕️ head shaking vertically down nod
🚶‍➡️ person walking facing right peerson exercise
🚶‍♀️‍➡️ woman walking facing right person exercise
🚶‍♂️‍➡️ man walking facing right person exercise
🧎‍➡️ person kneeling facing right pray
🧎‍♀️‍➡️ woman kneeling facing right pray worship
🧎‍♂️‍➡️ man kneeling facing right pray worship
🧑‍🦯‍➡️ person with white cane facing right walk walk visually impaired blind
👨‍🦯‍➡️ man with white cane facing right visually impaired blind walk stick
👩‍🦯‍➡️ woman with white cane facing right stick visually impaired blind
🧑‍🦼‍➡️ person in motorized wheelchair facing right accessibility disability
👨‍🦼‍➡️ man in motorized wheelchair facing right disability accessibility mobility
👩‍🦼‍➡️ woman in motorized wheelchair facing right mobility accessibility disability
🧑‍🦽‍➡️ person in manual wheelchair facing right mobility accessibility disability
👨‍🦽‍➡️ man in manual wheelchair facing right mobility accessibility disability
👩‍🦽‍➡️ woman in manual wheelchair facing right disability mobility accessibility
🏃‍➡️ person running facing right exercise jog
🏃‍♀️‍➡️ woman running facing right exercise jog
🏃‍♂️‍➡️ man running facing right jog exercise
🧑‍🧑‍🧒 family adult, adult, child kid parents
🧑‍🧑‍🧒‍🧒 family adult, adult, child, child children parents
🧑‍🧒 family adult, child parent kid
🧑‍🧒‍🧒 family adult, child, child parent children
🐦‍🔥 phoenix immortal bird mythtical reborn
🍋‍🟩 lime fruit acidic citric
🍄‍🟫 brown mushroom toadstool fungus
⛓️‍💥 broken chain constraint break
