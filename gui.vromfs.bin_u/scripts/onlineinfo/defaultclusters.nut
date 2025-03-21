let countryToCluster = {
  AM = "CIS" 
  AZ = "CIS" 
  BY = "CIS" 
  BG = "CIS" 
  HR = "CIS" 
  EE = "CIS" 
  FI = "CIS" 
  GE = "CIS" 
  HU = "CIS" 
  KZ = "CIS" 
  KG = "CIS" 
  LV = "CIS" 
  LT = "CIS" 
  MD = "CIS" 
  PL = "CIS" 
  RU = "CIS" 
  SK = "CIS" 
  SI = "CIS" 
  SE = "CIS" 
  TM = "CIS" 
  UZ = "CIS" 
  AF = "CIS" 
  BH = "CIS" 
  BD = "CIS" 
  BT = "CIS" 
  BN = "CIS" 
  KH = "CIS" 
  CX = "CIS" 
  CC = "CIS" 
  IO = "CIS" 
  HK = "CIS" 
  ID = "SA" 
  IR = "CIS" 
  IQ = "CIS" 
  IL = "CIS" 
  JO = "CIS" 
  KW = "CIS" 
  LB = "CIS" 
  MV = "CIS" 
  OM = "CIS" 
  PK = "CIS" 
  PS = "CIS" 
  QA = "CIS" 
  SA = "CIS" 
  SY = "CIS" 
  TJ = "CIS" 
  TR = "CIS" 
  AE = "CIS" 
  YE = "CIS" 

  AL = "EU" 
  AD = "EU" 
  AT = "EU" 
  BE = "EU" 
  BA = "EU" 
  CY = "EU" 
  CZ = "EU" 
  DK = "EU" 
  FO = "EU" 
  FR = "EU" 
  DE = "EU" 
  GI = "EU" 
  GR = "EU" 
  IS = "EU" 
  IE = "EU" 
  IM = "EU" 
  IT = "EU" 
  RS = "CIS" 
  LI = "EU" 
  LU = "EU" 
  MK = "EU" 
  MT = "EU" 
  MC = "EU" 
  ME = "EU" 
  NL = "EU" 
  NO = "EU" 
  PT = "EU" 
  RO = "EU" 
  SM = "EU" 
  ES = "EU" 
  CH = "EU" 
  UA = "EU" 
  GB = "EU" 
  VA = "EU" 

  AR = "NA" 
  BO = "NA" 
  BR = "NA" 
  CL = "NA" 
  CO = "NA" 
  EC = "NA" 
  FK = "NA" 
  GF = "NA" 
  GY = "NA" 
  PY = "NA" 
  PE = "NA" 
  SR = "NA" 
  UY = "NA" 
  VE = "NA" 
  AI = "NA" 
  AG = "NA" 
  AW = "NA" 
  BS = "NA" 
  BB = "NA" 
  BZ = "NA" 
  BM = "NA" 
  VG = "NA" 
  CA = "NA" 
  KY = "NA" 
  CR = "NA" 
  CU = "NA" 
  CW = "NA" 
  DM = "NA" 
  DO = "NA" 
  SV = "NA" 
  GL = "NA" 
  GD = "NA" 
  GP = "NA" 
  GT = "NA" 
  HT = "NA" 
  HN = "NA" 
  JM = "NA" 
  MQ = "NA" 
  MX = "NA" 
  MS = "NA" 
  KN = "NA" 
  NI = "NA" 
  PA = "NA" 
  PR = "NA" 
  BQ = "NA" 
  SX = "NA" 
  LC = "NA" 
  PM = "NA" 
  VC = "NA" 
  TT = "NA" 
  TC = "NA" 
  VI = "NA" 
  US = "NA" 
  AS = "NA" 
  AU = "SA;NA" 
  NZ = "SA;NA" 
  CK = "NA" 
  TL = "NA" 
  FM = "NA" 
  FJ = "NA" 
  PF = "NA" 
  GU = "NA" 
  KI = "NA" 
  MP = "NA" 
  MH = "NA" 
  UM = "NA" 
  NR = "NA" 
  NC = "NA" 
  NU = "NA" 
  NF = "NA" 
  PW = "NA" 
  PG = "NA" 
  WS = "NA" 
  SB = "NA" 
  TK = "NA" 
  TO = "NA" 
  TV = "NA" 
  VU = "NA" 
  WF = "NA" 

  CN = "SA" 
  IN = "SA" 
  JP = "SA" 
  LA = "SA" 
  MO = "SA" 
  MY = "SA" 
  MN = "SA" 
  MM = "SA" 
  NP = "SA" 
  KP = "SA" 
  PH = "SA" 
  SG = "SA" 
  KR = "SA" 
  LK = "SA" 
  TW = "SA" 
  TH = "SA" 
  VN = "SA" 
}

let getClustersByCountry = @(code) countryToCluster?[code].split_by_chars(";", true) ?? []

return {
  getClustersByCountry
}
