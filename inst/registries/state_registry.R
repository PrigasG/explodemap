# State registry for cross-state calibration
# Used by inst/examples/run_calibration.R
# Each entry contains FIPS, CRS, region map, and known-good parameters (if any)

state_registry <- list(

  NJ = list(
    name = "New Jersey", fips = "34", crs = 32118,
    region_map = list(
      North   = c("Bergen","Essex","Hudson","Morris","Passaic","Sussex","Union","Warren"),
      Central = c("Hunterdon","Mercer","Middlesex","Monmouth","Somerset"),
      South   = c("Atlantic","Burlington","Camden","Cape May","Cumberland",
                   "Gloucester","Ocean","Salem")
    ),
    known_alpha_r = 6000, known_alpha_l = 10000
  ),

  PA = list(
    name = "Pennsylvania", fips = "42", crs = 26918,
    region_map = list(
      Southeast    = c("Philadelphia","Delaware","Chester","Montgomery","Bucks"),
      Northeast    = c("Pike","Monroe","Carbon","Northampton","Lehigh","Luzerne",
                       "Lackawanna","Wayne","Susquehanna","Wyoming","Sullivan",
                       "Columbia","Montour","Schuylkill","Berks","Bradford"),
      Central      = c("Centre","Clinton","Lycoming","Tioga","Potter","Cameron",
                       "Elk","Clearfield","Jefferson","Indiana","Blair",
                       "Huntingdon","Mifflin","Snyder","Union","Northumberland",
                       "Juniata","Perry","Dauphin","Lebanon"),
      SouthCentral = c("York","Adams","Lancaster","Cumberland","Franklin",
                       "Fulton","Bedford","Somerset","Cambria"),
      Southwest    = c("Allegheny","Westmoreland","Fayette","Greene",
                       "Washington","Beaver","Butler","Armstrong","Lawrence"),
      Northwest    = c("Erie","Crawford","Mercer","Venango","Clarion",
                       "Forest","Warren","McKean")
    ),
    known_alpha_r = 25000, known_alpha_l = NA
  ),

  OH = list(
    name = "Ohio", fips = "39", crs = 32617,
    region_map = list(
      Northeast = c("Cuyahoga","Summit","Lorain","Lake","Medina","Portage","Geauga",
                    "Ashtabula","Trumbull","Mahoning","Columbiana","Carroll","Stark",
                    "Wayne","Holmes","Harrison","Jefferson"),
      Northwest = c("Lucas","Wood","Fulton","Williams","Defiance","Paulding","Henry",
                    "Putnam","Hancock","Sandusky","Erie","Ottawa","Seneca","Wyandot",
                    "Crawford","Huron","Ashland","Richland","Morrow","Knox","Marion",
                    "Hardin","Logan","Union","Delaware","Allen","Van Wert","Auglaize",
                    "Shelby","Mercer"),
      Central   = c("Franklin","Licking","Fairfield","Pickaway","Madison","Fayette",
                    "Ross","Clark","Greene","Montgomery","Preble","Darke","Miami","Champaign"),
      Southwest = c("Hamilton","Butler","Warren","Clermont","Clinton","Highland",
                    "Brown","Adams","Scioto","Lawrence","Gallia","Jackson","Pike"),
      Southeast = c("Belmont","Monroe","Washington","Meigs","Morgan","Noble","Guernsey",
                    "Muskingum","Perry","Hocking","Athens","Tuscarawas","Coshocton","Vinton")
    ),
    known_alpha_r = NA, known_alpha_l = NA
  ),

  NY = list(
    name = "New York", fips = "36", crs = 32618,
    region_map = list(
      NYC          = c("New York","Kings","Queens","Bronx","Richmond"),
      LongIsland   = c("Nassau","Suffolk"),
      HudsonValley = c("Westchester","Rockland","Orange","Putnam","Dutchess",
                       "Ulster","Sullivan","Columbia","Greene"),
      Upstate      = c("Albany","Rensselaer","Schenectady","Saratoga","Washington",
                       "Warren","Hamilton","Fulton","Montgomery","Schoharie","Otsego",
                       "Delaware","Chenango","Broome","Tioga","Tompkins","Cortland",
                       "Onondaga","Oswego","Madison","Oneida","Herkimer","Lewis",
                       "Jefferson","St. Lawrence","Franklin","Clinton","Essex"),
      Western      = c("Monroe","Ontario","Wayne","Seneca","Cayuga","Yates","Schuyler",
                       "Steuben","Chemung","Livingston","Allegany","Cattaraugus",
                       "Chautauqua","Erie","Niagara","Orleans","Genesee","Wyoming")
    ),
    known_alpha_r = NA, known_alpha_l = NA
  )
)
