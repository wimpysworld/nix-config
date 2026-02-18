{
  devices = {
    atrius = {
      id = "EKWH3CX-CPKKVGM-KWVNFTJ-AA5GGEU-KR3PRPE-2CC7DBG-K7YXOVO-24GGXAX";
    };
    bane = {
      id = "X7K3SCU-7KN62YR-NKAZQHW-V2JYRXP-JXGNXFO-QPPPPHX-3MQTO6B-XIK72Q3";
    };
    felkor = {
      id = "7E5FVLT-FHN6W2E-4FJI65X-DXV4PGJ-LSFGLRX-YIUTMHG-DBEKSLB-IWY2VQO";
    };
    malak = {
      id = "33YEJHX-NZB34VC-KB3LI2V-HFNOALL-7O2OLEB-SE75AWA-DWOC62K-5SRXMAC";
    };
    malgus = {
      id = "L6J7UDJ-O3WXU6L-HV5ANLQ-ADJJZP6-CFMU6G4-ZKRXUYB-3OWXI5A-TRBMGQ7";
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
    zannah = {
      id = "W7VBAM3-AC544LE-IF7IB4P-M744YPK-AXBYTYG-5YZHYZ6-PAFT645-ID7QRQ4";
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
        "malgus"
        "momin"
        "phasma"
        "revan"
        "vader"
        "zannah"
      ];
    };
    audio = {
      id = "audio";
      label = "Audio";
      maxConflicts = 10;
      path = "~/Audio";
      devices = [
        "bane"
        "malgus"
        "phasma"
        "revan"
        "vader"
        "zannah"
      ];
    };
    chainguard = {
      id = "chainguard";
      label = "Chainguard";
      maxConflicts = 10;
      path = "~/Chainguard";
      devices = [
        "bane"
        "malgus"
        "phasma"
        "vader"
        "zannah"
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
        "felkor"
        "malak"
        "malgus"
        "maul"
        "momin"
        "phasma"
        "revan"
        "shaa"
        "sidious"
        "tanis"
        "vader"
        "zannah"
      ];
    };
    development = {
      id = "development";
      label = "Development";
      maxConflicts = 10;
      path = "~/Development";
      devices = [
        "bane"
        "malgus"
        "momin"
        "phasma"
        "vader"
        "zannah"
      ];
    };
    documents = {
      id = "documents";
      label = "Documents";
      maxConflicts = 10;
      path = "~/Documents";
      devices = [
        "bane"
        "malgus"
        "momin"
        "phasma"
        "revan"
        "vader"
        "zannah"
      ];
    };
    downloads = {
      id = "downloads";
      label = "Downloads";
      maxConflicts = 10;
      path = "~/Downloads";
      devices = [
        "bane"
        "malgus"
        "momin"
        "phasma"
        "revan"
        "vader"
        "zannah"
      ];
    };
    games = {
      id = "games";
      label = "Games";
      maxConflicts = 10;
      path = "~/Games";
      devices = [
        "malgus"
        "phasma"
        "vader"
        "zannah"
      ];
    };
    music = {
      id = "music";
      label = "Music";
      maxConflicts = 10;
      path = "~/Music";
      devices = [
        "malgus"
        "phasma"
        "vader"
        "zannah"
      ];
    };
    pictures = {
      id = "pictures";
      label = "Pictures";
      maxConflicts = 10;
      path = "~/Pictures";
      devices = [
        "bane"
        "malgus"
        "phasma"
        "revan"
        "vader"
        "zannah"
      ];
    };
    studio = {
      id = "studio";
      label = "Studio";
      maxConflicts = 10;
      path = "~/Studio";
      devices = [
        "malgus"
        "phasma"
        "revan"
        "vader"
        "zannah"
      ];
    };
    videos = {
      id = "videos";
      label = "Videos";
      maxConflicts = 10;
      path = "~/Videos";
      devices = [
        "malgus"
        "phasma"
        "vader"
        "zannah"
      ];
    };
  };
}
