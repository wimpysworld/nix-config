{ pkgs }:

pkgs.writeScriptBin "simple-password" ''
#!${pkgs.stdenv.shell}
# Creates a pseudo random password
function create_password {
    # Create an array of 3 letter words
    WORDS=(
    Ace Act Add Aft Age Ago Aid Ail Aim Air
    All Alp Amp And Ant Any Ape Apt Arc Ark
    Art Ash Ask Asp Ass Ate Awe Axe Aye Bad
    Ban Bap Bar Bat Bay Bed Bee Beg Bet Bib
    Bin Bit Boa Bob Bog Bow Boy Bud Bug Bum
    Bur Bus But Buy Bye Cab Cad Can Cap Car
    Cob Cod Cog Con Cop Cot Cow Cox Coy Cry
    Cud Cue Cup Cur Cut Dab Day Den Dew Did
    Dig Dim Din Dip Doe Dog Don Dot Dry Dub
    Dug Duo Dye Ear Eat Eft Egg Ego Emu Eve
    Eye Fab Fad Fag Fan Far Fat Few Fez Fib
    Fir Fit Fix Fly Fob Foe Fog Fop For Fox
    Fun Fur Gag Gap Gas Gay Gel Gem Get Gig
    Git Gnu Got Gum Gun Gut Guy Gym Hag Ham
    Hat Hay Hem Her Hew Hex Hey Hid Him Hip
    Hit Hob Hod Hoe Hog Hop Hot How Hub Hue
    Hum Hut Ice Icy Ilk Ill Ink Inn Ion Irk
    Jab Jag Jam Jar Jaw Jay Jet Jig Job Jog
    Joy Jug Jut Keg Key Kid Kin Kip Kit Lab
    Lag Lap Law Lay Led Leg Let Lid Lie Lip
    Lob Log Lop Lot Low Lug Mac Mad Mag Man
    Mat Max May Men Met Mew Mid Mix Mob Mop
    Mud Mug Mum Nab Nag Nap Nay Net New Nib
    Nip Nit Nod Not Now Nub Nun Nut Oaf Oak
    Oat Odd Ode Oft Ohm Oil Old One Opt Orb
    Owl Own Pad Pan Par Pat Paw Pay Pea Peg
    Pet Pew Pie Pig Pin Pit Ply Pod Pop Pot
    Pro Pry Pub Pun Pup Pur Put Quo Rag Ram
    Rap Rat Raw Ray Red Rev Rib Rid Rig Rim
    Rob Rod Roe Rot Row Rub Rue Rug Rum Run
    Sad Sap Sat Saw Say Sea See Set Sew Sex
    Shy Sin Sip Sir Sit Six Sky Sly Sob Sod
    Sow Spy Sty Sum Sun Tag Tan Tap Tar Tax
    Tee Ten The Thy Tie Tin Tip Tit Toe Ton
    Top Tor Tow Try Tub Tug Two Urn Use Van
    Vet Vex Via Vie Vim Vow Wad Wag War Wax
    Web Wed Wet Who Why Wig Win Wit Wok Won
    Wry Wye Yak Yam Yap Yes Yet Yob You Yum
    Zag Zap Zed Zen Zig Zip Zit Zoo
    )

    # Create an array of numbers
    NUMBERS=( 1 2 3 4 5 6 7 8 9 0 )

    # Create an array of "special" characters
    CHARS=( ! . )

    MOD_WORD=$#WORDS[*]
    MOD_NUM=$#NUMBERS[*]
    MOD_CHAR=$#CHARS[*]

    IDX_NUM=$(($RANDOM%$MOD_NUM))
    IDX_CHAR=$(($RANDOM%$MOD_CHAR))

    LENGTH=0
    while [ $LENGTH -lt 2 ]; do
        IDX_WORD=$(($RANDOM%$MOD_WORD))
        echo -n "$WORDS[$IDX_WORD]}"
        ((LENGTH++))

        if [ $LENGTH -eq 1 ]; then
            echo -n "$NUMBERS[$IDX_NUM]"
        fi

        if [ $LENGTH -eq 2 ]; then
            echo -n "$CHARS[$IDX_CHAR]"
        fi
    done
}

SIMPLE_PASSWORD=$(create_password)
${pkgs.coreutils-full}/bin/echo "$SIMPLE_PASSWORD"
''
