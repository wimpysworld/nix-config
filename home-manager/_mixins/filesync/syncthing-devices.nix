{
  devices = {
    atrius = {
      id = "EKWH3CX-CPKKVGM-KWVNFTJ-AA5GGEU-KR3PRPE-2CC7DBG-K7YXOVO-24GGXAX";
    };
    bane = {
      id = "X7K3SCU-7KN62YR-NKAZQHW-V2JYRXP-JXGNXFO-QPPPPHX-3MQTO6B-XIK72Q3";
    };
    malak = {
      id = "33YEJHX-NZB34VC-KB3LI2V-HFNOALL-7O2OLEB-SE75AWA-DWOC62K-5SRXMAC";
    };
    maul = {
      id = "ZEAIH76-MXTIJIT-NAO7XPT-CDGUM4D-PREAAQG-6Z3LVD5-47PB6ZB-KDCRCAS";
    };
    momin = {
      id = "BLSBPMB-XMTHCAA-FJWY57S-XBIH5Y2-25IERPU-7SL3CX3-EWF7HQ7-HYXU6A6";
    };
    phasma = {
      id = "5TRHOB7-UOUNOOX-JJLXYMP-I6ZSL2J-IX2ULR5-X6HPHAD-PZ3I6FF-CWHCTAV";
    };
    revan = {
      id = "AVBGEWD-VDVP7JE-T5MHZAG-CZVDIFZ-2F37L7T-IBY4ZIM-O5OOLN3-JV3ZDQA";
    };
    shaa = {
      id = "C2GVYBM-C7ORBKW-5EDAJ4R-OFPYMQG-357GAV2-MIMT7EM-DK4X6AS-IQ7HZQF";
    };
    sidious = {
      id = "ZMYGCVY-ACFU63O-JXDZKLK-ABIKGC7-GWZMBZY-WQKIHCH-RQIUXM6-DM2RKAE";
    };
    tanis = {
      id = "7VNA2SU-UNVYIFI-UQAXBV5-LZ2F2FQ-TARFAMJ-L4IC5OE-UHQJLRC-UKCV7AB";
    };
    vader = {
      id = "TTRWY3V-22LRBHF-7LVDDX7-ADRHXG5-HQJYS5F-K35PUBJ-AXYXKEJ-MGXHNQR";
    };
  };

  folders = {
    apps = {
      id = "apps";
      label = "Apps";
      maxConflicts = 10;
      path = "~/Apps";
      devices = [
        "bane"
        "momin"
        "phasma"
        "revan"
        "vader"
      ];
    };
    audio = {
      id = "audio";
      label = "Audio";
      maxConflicts = 10;
      path = "~/Audio";
      devices = [
        "bane"
        "phasma"
        "revan"
        "vader"
      ];
    };
    chainguard = {
      id = "chainguard";
      label = "Chainguard";
      maxConflicts = 10;
      path = "~/Chainguard";
      devices = [
        "bane"
        "phasma"
        "vader"
      ];
    };
    crypt = {
      id = "crypt";
      label = "Crypt";
      maxConflicts = 10;
      path = "~/Crypt";
      devices = [
        "atrius"
        "bane"
        "malak"
        "maul"
        "momin"
        "phasma"
        "revan"
        "shaa"
        "sidious"
        "tanis"
        "vader"
      ];
    };
    development = {
      id = "development";
      label = "Development";
      maxConflicts = 10;
      path = "~/Development";
      devices = [
        "bane"
        "momin"
        "phasma"
        "tanis"
        "vader"
      ];
    };
    documents = {
      id = "documents";
      label = "Documents";
      maxConflicts = 10;
      path = "~/Documents";
      devices = [
        "bane"
        "momin"
        "phasma"
        "revan"
        "vader"
      ];
    };
    downloads = {
      id = "downloads";
      label = "Downloads";
      maxConflicts = 10;
      path = "~/Downloads";
      devices = [
        "bane"
        "momin"
        "phasma"
        "revan"
        "vader"
      ];
    };
    games = {
      id = "games";
      label = "Games";
      maxConflicts = 10;
      path = "~/Games";
      devices = [
        "phasma"
        "vader"
      ];
    };
    music = {
      id = "music";
      label = "Music";
      maxConflicts = 10;
      path = "~/Music";
      devices = [
        "phasma"
        "vader"
      ];
    };
    pictures = {
      id = "pictures";
      label = "Pictures";
      maxConflicts = 10;
      path = "~/Pictures";
      devices = [
        "bane"
        "phasma"
        "revan"
        "vader"
      ];
    };
    studio = {
      id = "studio";
      label = "Studio";
      maxConflicts = 10;
      path = "~/Studio";
      devices = [
        "phasma"
        "revan"
        "vader"
      ];
    };
    videos = {
      id = "videos";
      label = "Videos";
      maxConflicts = 10;
      path = "~/Videos";
      devices = [
        "phasma"
        "vader"
      ];
    };
  };
}
