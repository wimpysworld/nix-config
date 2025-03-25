#!/usr/bin/env bash

# Creates a pseudo random password
function create_password {
    # Create an array of 3 letter words
    WORDS=(
    Aah Ace Act Add Aft Age Ago Aha Aid Ail
    Aim Air Ale All Alp Amp And Ant Any Ape
    Apt Arc Are Ark Arm Art Ash Ask Asp Ass
    Ate Awe Awn Axe Aye Bad Bag Bam Ban Bap
    Bar Bat Bay Bed Bee Beg Bet Bib Big Bin
    Bio Bit Boa Bob Bog Boo Bop Bot Bow Box
    Boy Bra Bud Bug Bum Bun Bur Bus But Buy
    Bye Cab Cad Can Cap Car Cat Caw Cob Cod
    Cog Con Cop Cot Cow Cox Coy Cry Cud Cue
    Cub Cup Cur Cut Dab Dad Dag Day Def Den
    Dew Dex Did Die Dig Dim Din Dip Doe Dog
    Don Dot Dry Dub Dud Dug Duo Dye Ear Eat
    Eco Eft Egg Ego Elf Elk Elm Emo Emu End
    Eon Era Eve Ewe Eye Fab Fad Fag Fan Far
    Fat Fax Fed Fee Fen Few Fez Fib Fig Fir
    Fit Fix Flu Fly Fob Foe Fog Foo Fop For
    Foy Fox Fry Fun Fur Gad Gag Gap Gas Gay
    Gel Gem Get Gig Gin Git Gnu Gob God Goo
    Got Gum Gun Gut Guy Gym Had Hag Hah Ham
    Has Hat Haw Hay Hem Her Het Hew Hex Hey
    Hid Him Hip His Hit Hob Hod Hoe Hog Hop
    Hot How Hub Hue Hug Hum Hut Ice Icy Ilk
    Ill Imp Ink Inn Ion Ire Irk Ivy Jab Jag
    Jam Jar Jaw Jay Jet Jib Jig Jin Job Jog
    Jot Joy Jug Jut Kay Keg Key Kid Kin Kip
    Kit Koi Kop Lab Lad Lag Lap Lav Law Lax
    Lay Led Leg Let Leu Lid Lie Lip Lit Lob
    Log Lop Lot Low Lox Lug Lux Mac Mad Mag
    Mam Man Map Mat Max May Meg Meh Men Met
    Mew Mic Mid Mig Mir Mix Mob Mod Mol Mom
    Moo Mop Mow Mud Mug Mum Nab Nag Nan Nap
    Nay Net New Nib Nip Nit Nix Nod Not Now
    Nub Nun Nut Oaf Oak Oar Oat Odd Ode Oft
    Ohm Oil Old One Oof Ooh Opt Orb Orc Ore
    Our Out Owe Owl Own Owt Pad Pal Pan Par
    Pat Paw Pay Pea Pee Peg Pen Pet Pew Pie
    Pig Pin Pip Pit Ply Pod Poo Pop Pot Pow
    Pox Pro Pry Pub Pug Pun Pup Pur Put Quo
    Rad Rag Ram Ran Rap Rat Raw Ray Red Rev
    Rib Rid Rig Rim Rip Rob Rod Roe Rot Row
    Rub Rue Rug Rum Run Rut Rye Sad Sag Sap
    Sat Saw Say Sea See Set Sew Sex She Shy
    Sin Sip Sir Sit Six Ska Ski Sky Sly Sob
    Sod Son Sow Spa Spy Sty Sub Sum Sun Tab
    Tad Tag Tan Tap Tar Tat Tax Tea Tee Ten
    The Thy Tie Tin Tip Tit Toe Tog Ton Too
    Top Tor Tow Toy Try Tsk Tub Tug Tut Two
    Ugh Urn Use Van Vat Veg Vet Vex Via Vie
    Vim Vow Wad Wag War Was Wax Way Web Wed
    Wee Wet Who Why Wig Win Wit Woe Wok Won
    Wow Wry Wye Yak Yam Yap Yaw Yay Yep Yes
    Yet Yob You Yum Zag Zap Zed Zee Zen Zig
    Zip Zit Zoo
    )

    # Create an array of numbers
    NUMBERS=( 1 2 3 4 5 6 7 8 9 0 )

    # Create an array of "special" characters
    CHARS=( ! . )

    MOD_WORD=${#WORDS[*]}
    MOD_NUM=${#NUMBERS[*]}
    MOD_CHAR=${#CHARS[*]}

    IDX_NUM=$((RANDOM%MOD_NUM))
    IDX_CHAR=$((RANDOM%MOD_CHAR))

    LENGTH=0
    while [ $LENGTH -lt 2 ]; do
        IDX_WORD=$((RANDOM%MOD_WORD))
        echo -n "${WORDS[$IDX_WORD]}"
        ((LENGTH++))

        if [ $LENGTH -eq 1 ]; then
            echo -n "${NUMBERS[$IDX_NUM]}"
        fi

        if [ $LENGTH -eq 2 ]; then
            echo -n "${CHARS[$IDX_CHAR]}"
        fi
    done
}

create_password
