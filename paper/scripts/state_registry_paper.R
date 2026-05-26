download_state_counties_for_registry <- function(fips, crs) {
  cache_file <- file.path(path.expand("~"), "explode_map_cache", "us_counties_2024.rds")
  if (file.exists(cache_file)) {
    counties <- readRDS(cache_file)
  } else {
    url <- "https://www2.census.gov/geo/tiger/TIGER2024/COUNTY/tl_2024_us_county.zip"
    tmp <- tempfile(fileext = ".zip")
    utils::download.file(url, tmp, mode = "wb", quiet = TRUE)
    dir <- file.path(tempdir(), "us_counties_2024")
    dir.create(dir, showWarnings = FALSE)
    utils::unzip(tmp, exdir = dir)
    shp <- list.files(dir, pattern = "\\.shp$", recursive = TRUE, full.names = TRUE)
    counties <- sf::st_read(shp[1], quiet = TRUE)
    dir.create(dirname(cache_file), showWarnings = FALSE, recursive = TRUE)
    saveRDS(counties, cache_file)
  }

  counties |>
    dplyr::filter(.data$STATEFP == fips) |>
    sf::st_transform(crs)
}

make_cluster_region_map <- function(fips, crs, centers, label_fun, seed = 2026) {
  counties <- download_state_counties_for_registry(fips, crs)
  xy <- sf::st_coordinates(sf::st_point_on_surface(sf::st_geometry(counties)))
  set.seed(seed)
  fit <- stats::kmeans(scale(xy), centers = centers, nstart = 50)
  cluster_centers <- data.frame(
    cluster = seq_len(centers),
    x = tapply(xy[, 1], fit$cluster, mean),
    y = tapply(xy[, 2], fit$cluster, mean)
  )
  cluster_labels <- label_fun(cluster_centers)
  labels <- cluster_labels[as.character(fit$cluster)]
  split(counties$NAME, labels)
}

label_texas_clusters <- function(centers) {
  remaining <- centers$cluster
  labels <- character(nrow(centers))

  panhandle <- centers$cluster[which.max(centers$y)]
  labels[panhandle] <- "Panhandle"
  remaining <- setdiff(remaining, panhandle)

  west <- remaining[which.min(centers$x[match(remaining, centers$cluster)])]
  labels[west] <- "West"
  remaining <- setdiff(remaining, west)

  gulf <- remaining[which.min(centers$y[match(remaining, centers$cluster)])]
  labels[gulf] <- "Gulf"
  remaining <- setdiff(remaining, gulf)

  east <- remaining[which.max(centers$x[match(remaining, centers$cluster)])]
  labels[east] <- "East"
  remaining <- setdiff(remaining, east)

  north_central <- remaining[which.max(centers$y[match(remaining, centers$cluster)])]
  labels[north_central] <- "NorthCentral"
  remaining <- setdiff(remaining, north_central)

  labels[remaining] <- "Central"
  stats::setNames(labels, centers$cluster)
}

label_florida_clusters <- function(centers) {
  remaining <- centers$cluster
  labels <- character(nrow(centers))

  panhandle <- centers$cluster[which.min(centers$x)]
  labels[panhandle] <- "Panhandle"
  remaining <- setdiff(remaining, panhandle)

  south <- remaining[which.min(centers$y[match(remaining, centers$cluster)])]
  labels[south] <- "South"
  remaining <- setdiff(remaining, south)

  north <- remaining[which.max(centers$y[match(remaining, centers$cluster)])]
  labels[north] <- "North"
  remaining <- setdiff(remaining, north)

  labels[remaining] <- "Central"
  stats::setNames(labels, centers$cluster)
}

label_kentucky_clusters <- function(centers) {
  remaining <- centers$cluster
  labels <- character(nrow(centers))

  east <- centers$cluster[which.max(centers$x)]
  labels[east] <- "East"
  remaining <- setdiff(remaining, east)

  west <- remaining[which.min(centers$x[match(remaining, centers$cluster)])]
  labels[west] <- "West"
  remaining <- setdiff(remaining, west)

  south <- remaining[which.min(centers$y[match(remaining, centers$cluster)])]
  labels[south] <- "South"
  remaining <- setdiff(remaining, south)

  north <- remaining[which.max(centers$y[match(remaining, centers$cluster)])]
  labels[north] <- "Bluegrass"
  remaining <- setdiff(remaining, north)

  labels[remaining] <- "Central"
  stats::setNames(labels, centers$cluster)
}

label_illinois_clusters <- function(centers) {
  remaining <- centers$cluster
  labels <- character(nrow(centers))

  # Northernmost cluster captures the Chicago metro area
  north <- centers$cluster[which.max(centers$y)]
  labels[north] <- "North"
  remaining <- setdiff(remaining, north)

  south <- remaining[which.min(centers$y[match(remaining, centers$cluster)])]
  labels[south] <- "South"
  remaining <- setdiff(remaining, south)

  # Of the two middle clusters, the higher-y one is CentralNorth
  central_n <- remaining[which.max(centers$y[match(remaining, centers$cluster)])]
  labels[central_n] <- "CentralNorth"
  remaining <- setdiff(remaining, central_n)

  labels[remaining] <- "CentralSouth"
  stats::setNames(labels, centers$cluster)
}

label_virginia_clusters <- function(centers) {
  remaining <- centers$cluster
  labels <- character(nrow(centers))

  # Northern Virginia — highest combined x + y score (northeast corner)
  score_all <- centers$x + centers$y
  northern <- centers$cluster[which.max(score_all)]
  labels[northern] <- "Northern"
  remaining <- setdiff(remaining, northern)

  # Southwest Virginia — westernmost of the remaining
  west <- remaining[which.min(centers$x[match(remaining, centers$cluster)])]
  labels[west] <- "Southwest"
  remaining <- setdiff(remaining, west)

  # Tidewater / Hampton Roads — easternmost AND southernmost (high x, low y)
  tidewater_score <- centers$x[match(remaining, centers$cluster)] -
    centers$y[match(remaining, centers$cluster)]
  tidewater <- remaining[which.max(tidewater_score)]
  labels[tidewater] <- "Tidewater"
  remaining <- setdiff(remaining, tidewater)

  # Shenandoah Valley — next westernmost
  valley <- remaining[which.min(centers$x[match(remaining, centers$cluster)])]
  labels[valley] <- "Valley"
  remaining <- setdiff(remaining, valley)

  labels[remaining] <- "Piedmont"
  stats::setNames(labels, centers$cluster)
}

label_georgia_clusters <- function(centers) {
  remaining <- centers$cluster
  labels <- character(nrow(centers))

  # Atlanta metro — highest combined x + y + density proxy (NE quadrant)
  score <- centers$x + centers$y
  north <- centers$cluster[which.max(score)]
  labels[north] <- "North"
  remaining <- setdiff(remaining, north)

  east <- remaining[which.max(centers$x[match(remaining, centers$cluster)])]
  labels[east] <- "East"
  remaining <- setdiff(remaining, east)

  west <- remaining[which.min(centers$x[match(remaining, centers$cluster)])]
  labels[west] <- "West"
  remaining <- setdiff(remaining, west)

  south <- remaining[which.min(centers$y[match(remaining, centers$cluster)])]
  labels[south] <- "South"
  remaining <- setdiff(remaining, south)

  labels[remaining] <- "Central"
  stats::setNames(labels, centers$cluster)
}

label_minnesota_clusters <- function(centers) {
  remaining <- centers$cluster
  labels <- character(nrow(centers))

  north <- centers$cluster[which.max(centers$y)]
  labels[north] <- "North"
  remaining <- setdiff(remaining, north)

  south <- remaining[which.min(centers$y[match(remaining, centers$cluster)])]
  labels[south] <- "South"
  remaining <- setdiff(remaining, south)

  # Twin Cities metro — highest x among the middle two (more eastern)
  metro <- remaining[which.max(centers$x[match(remaining, centers$cluster)])]
  labels[metro] <- "Metro"
  remaining <- setdiff(remaining, metro)

  labels[remaining] <- "Central"
  stats::setNames(labels, centers$cluster)
}

label_california_clusters <- function(centers) {
  remaining <- centers$cluster
  labels <- character(nrow(centers))

  # NorCal — northernmost
  norcal <- centers$cluster[which.max(centers$y)]
  labels[norcal] <- "NorCal"
  remaining <- setdiff(remaining, norcal)

  # SoCal — southernmost
  socal <- remaining[which.min(centers$y[match(remaining, centers$cluster)])]
  labels[socal] <- "SoCal"
  remaining <- setdiff(remaining, socal)

  # Bay Area — westernmost of the remaining (coastal, mid-latitude)
  bayarea <- remaining[which.min(centers$x[match(remaining, centers$cluster)])]
  labels[bayarea] <- "BayArea"
  remaining <- setdiff(remaining, bayarea)

  # Central Valley — lowest y among remaining two
  cv <- remaining[which.min(centers$y[match(remaining, centers$cluster)])]
  labels[cv] <- "CentralValley"
  remaining <- setdiff(remaining, cv)

  labels[remaining] <- "Central"
  stats::setNames(labels, centers$cluster)
}

paper_state_registry <- list(
  NJ = list(
    name = "New Jersey",
    fips = "34",
    crs = 32111,
    region_map = list(
      North = c("Bergen", "Essex", "Hudson", "Morris", "Passaic", "Sussex", "Union", "Warren"),
      Central = c("Hunterdon", "Mercer", "Middlesex", "Monmouth", "Somerset"),
      South = c("Atlantic", "Burlington", "Camden", "Cape May", "Cumberland", "Gloucester", "Ocean", "Salem")
    ),
    manual_alpha_r = 6000,
    manual_alpha_l = 10000,
    manual_protocol = "Author-selected visual calibration reference used in the exploratory NJ prototype."
  ),

  PA = list(
    name = "Pennsylvania",
    fips = "42",
    crs = 26918,
    region_map = list(
      Southeast = c("Philadelphia", "Delaware", "Chester", "Montgomery", "Bucks"),
      Northeast = c("Pike", "Monroe", "Carbon", "Northampton", "Lehigh", "Luzerne",
                    "Lackawanna", "Wayne", "Susquehanna", "Wyoming", "Sullivan",
                    "Columbia", "Montour", "Schuylkill", "Berks", "Bradford"),
      Central = c("Centre", "Clinton", "Lycoming", "Tioga", "Potter", "Cameron",
                  "Elk", "Clearfield", "Jefferson", "Indiana", "Blair",
                  "Huntingdon", "Mifflin", "Snyder", "Union", "Northumberland",
                  "Juniata", "Perry", "Dauphin", "Lebanon"),
      SouthCentral = c("York", "Adams", "Lancaster", "Cumberland", "Franklin",
                       "Fulton", "Bedford", "Somerset", "Cambria"),
      Southwest = c("Allegheny", "Westmoreland", "Fayette", "Greene",
                    "Washington", "Beaver", "Butler", "Armstrong", "Lawrence"),
      Northwest = c("Erie", "Crawford", "Mercer", "Venango", "Clarion",
                    "Forest", "Warren", "McKean")
    ),
    manual_alpha_r = 25000,
    manual_alpha_l = NA_real_,
    manual_protocol = "PA alpha_r came from exploratory visual tuning; PA alpha_l=40000 was heuristic and is not treated as ground truth."
  ),

  OH = list(
    name = "Ohio",
    fips = "39",
    crs = 32617,
    region_map = list(
      Northeast = c("Cuyahoga", "Summit", "Lorain", "Lake", "Medina", "Portage", "Geauga",
                    "Ashtabula", "Trumbull", "Mahoning", "Columbiana", "Carroll", "Stark",
                    "Wayne", "Holmes", "Harrison", "Jefferson"),
      Northwest = c("Lucas", "Wood", "Fulton", "Williams", "Defiance", "Paulding", "Henry",
                    "Putnam", "Hancock", "Sandusky", "Erie", "Ottawa", "Seneca", "Wyandot",
                    "Crawford", "Huron", "Ashland", "Richland", "Morrow", "Knox", "Marion",
                    "Hardin", "Logan", "Union", "Delaware", "Allen", "Van Wert", "Auglaize",
                    "Shelby", "Mercer", "Champaign"),
      Central = c("Franklin", "Licking", "Fairfield", "Pickaway", "Madison", "Fayette",
                  "Ross", "Clark", "Greene", "Montgomery", "Preble", "Darke", "Miami"),
      Southwest = c("Hamilton", "Butler", "Warren", "Clermont", "Clinton", "Highland",
                    "Brown", "Adams", "Scioto", "Lawrence", "Gallia", "Jackson", "Pike"),
      Southeast = c("Belmont", "Monroe", "Washington", "Meigs", "Morgan", "Noble", "Guernsey",
                    "Muskingum", "Perry", "Hocking", "Athens", "Tuscarawas", "Coshocton", "Vinton")
    ),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = NA_character_
  ),

  MI = list(
    name = "Michigan",
    fips = "26",
    crs = 32616,
    region_map = list(
      UpperPeninsula = c("Gogebic", "Ontonagon", "Houghton", "Keweenaw", "Baraga",
                         "Iron", "Dickinson", "Menominee", "Marquette", "Alger",
                         "Schoolcraft", "Delta", "Luce", "Mackinac", "Chippewa"),
      Northern = c("Emmet", "Cheboygan", "Presque Isle", "Montmorency",
                   "Otsego", "Antrim", "Charlevoix", "Benzie", "Leelanau",
                   "Grand Traverse", "Kalkaska", "Crawford", "Oscoda",
                   "Alpena", "Alcona", "Iosco", "Ogemaw", "Roscommon",
                   "Missaukee", "Wexford", "Osceola", "Clare", "Gladwin",
                   "Arenac", "Bay", "Huron", "Tuscola", "Sanilac", "Manistee"),
      Metro = c("Wayne", "Oakland", "Macomb", "Washtenaw", "Livingston",
                "Monroe", "St. Clair", "Lapeer", "Genesee", "Shiawassee",
                "Ingham", "Eaton", "Clinton", "Kent", "Ottawa", "Muskegon",
                "Allegan", "Barry", "Ionia", "Montcalm", "Gratiot", "Saginaw", "Midland"),
      Southern = c("Berrien", "Cass", "Van Buren", "Kalamazoo", "St. Joseph",
                   "Branch", "Calhoun", "Jackson", "Hillsdale", "Lenawee",
                   "Mason", "Lake", "Newaygo", "Mecosta", "Isabella", "Oceana")
    ),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = NA_character_
  ),

  TX = list(
    name = "Texas",
    fips = "48",
    crs = 32614,
    region_map = function() make_cluster_region_map("48", 32614, 6, label_texas_clusters),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = "County groups were generated reproducibly from county centroid k-means clusters for exploratory cross-state validation."
  ),

  FL = list(
    name = "Florida",
    fips = "12",
    crs = 3086,
    region_map = function() make_cluster_region_map("12", 3086, 4, label_florida_clusters),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = "County groups were generated reproducibly from county centroid k-means clusters for exploratory cross-state validation."
  ),

  # ---------------------------------------------------------------------------
  # New states added for expanded paper examples
  # ---------------------------------------------------------------------------

  KY = list(
    name = "Kentucky",
    fips = "21",
    crs = 32616,
    region_map = function() make_cluster_region_map("21", 32616, 5, label_kentucky_clusters),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = "County groups were generated reproducibly from county centroid k-means clusters."
  ),

  IL = list(
    name = "Illinois",
    fips = "17",
    crs = 32616,
    region_map = function() make_cluster_region_map("17", 32616, 4, label_illinois_clusters),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = "County groups were generated reproducibly from county centroid k-means clusters."
  ),

  ND = list(
    name = "North Dakota",
    fips = "38",
    crs = 32614,
    region_map = list(
      West = c("Adams", "Billings", "Bowman", "Burke", "Divide", "Dunn",
               "Golden Valley", "Grant", "Hettinger", "McKenzie", "Mercer",
               "Morton", "Mountrail", "Oliver", "Slope", "Stark", "Williams"),
      Central = c("Bottineau", "Burleigh", "Emmons", "Foster", "Kidder",
                  "LaMoure", "Logan", "McHenry", "McIntosh", "McLean",
                  "Pierce", "Renville", "Rolette", "Sheridan", "Sioux",
                  "Stutsman", "Towner", "Ward", "Wells", "Benson"),
      East = c("Barnes", "Cass", "Cavalier", "Dickey", "Eddy",
               "Grand Forks", "Griggs", "Nelson", "Pembina", "Ramsey",
               "Ransom", "Richland", "Sargent", "Steele", "Traill", "Walsh")
    ),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = NA_character_
  ),

  NC = list(
    name = "North Carolina",
    fips = "37",
    crs = 32617,
    region_map = list(
      Mountains = c("Alleghany", "Ashe", "Avery", "Buncombe", "Burke",
                    "Caldwell", "Cherokee", "Clay", "Graham", "Haywood",
                    "Henderson", "Jackson", "McDowell", "Macon", "Madison",
                    "Mitchell", "Polk", "Rutherford", "Swain", "Transylvania",
                    "Watauga", "Wilkes", "Yancey"),
      Piedmont = c("Alamance", "Alexander", "Cabarrus", "Catawba", "Chatham",
                   "Cleveland", "Davidson", "Davie", "Durham", "Forsyth",
                   "Gaston", "Guilford", "Iredell", "Lee", "Lincoln",
                   "Mecklenburg", "Montgomery", "Moore", "Orange", "Person",
                   "Caswell", "Randolph", "Rockingham", "Rowan", "Stanly", "Stokes",
                   "Surry", "Union", "Yadkin"),
      CoastalPlain = c("Anson", "Beaufort", "Bertie", "Bladen", "Brunswick",
                       "Camden", "Carteret", "Chowan", "Columbus", "Craven",
                       "Cumberland", "Currituck", "Dare", "Duplin", "Edgecombe",
                       "Franklin", "Gates", "Granville", "Greene", "Halifax",
                       "Harnett", "Hertford", "Hoke", "Hyde", "Johnston",
                       "Jones", "Lenoir", "Martin", "Nash", "New Hanover",
                       "Northampton", "Onslow", "Pamlico", "Pasquotank",
                       "Pender", "Perquimans", "Pitt", "Richmond", "Robeson",
                       "Sampson", "Scotland", "Tyrrell", "Vance", "Wake",
                       "Warren", "Washington", "Wayne", "Wilson")
    ),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = NA_character_
  ),

  VA = list(
    name = "Virginia",
    fips = "51",
    crs = 32618,
    region_map = function() make_cluster_region_map("51", 32618, 5, label_virginia_clusters),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = "County groups were generated reproducibly from county centroid k-means clusters. Virginia independent cities are included as separate features alongside counties."
  ),

  # ---------------------------------------------------------------------------
  # Second wave: TN, GA, MN, CA, CO  (added 2026-05)
  # ---------------------------------------------------------------------------

  TN = list(
    name = "Tennessee",
    fips = "47",
    crs = 32616,
    region_map = list(
      East   = c("Anderson", "Bledsoe", "Blount", "Bradley", "Campbell", "Carter",
                 "Claiborne", "Cocke", "Cumberland", "Grainger", "Greene", "Hamblen",
                 "Hamilton", "Hancock", "Hawkins", "Jefferson", "Johnson", "Knox",
                 "Loudon", "McMinn", "Meigs", "Monroe", "Morgan", "Polk", "Rhea",
                 "Roane", "Scott", "Sequatchie", "Sevier", "Sullivan", "Unicoi",
                 "Union", "Washington", "Marion"),
      Middle = c("Bedford", "Cannon", "Cheatham", "Clay", "Coffee", "Davidson",
                 "DeKalb", "Dickson", "Fentress", "Franklin", "Giles", "Grundy",
                 "Hickman", "Houston", "Humphreys", "Jackson", "Lawrence", "Lewis",
                 "Lincoln", "Macon", "Marshall", "Maury", "Montgomery", "Moore",
                 "Overton", "Perry", "Pickett", "Putnam", "Robertson", "Rutherford",
                 "Smith", "Stewart", "Sumner", "Trousdale", "Van Buren", "Warren",
                 "Wayne", "White", "Williamson", "Wilson"),
      West   = c("Benton", "Carroll", "Chester", "Crockett", "Decatur", "Dyer",
                 "Fayette", "Gibson", "Hardeman", "Hardin", "Haywood", "Henderson",
                 "Henry", "Lake", "Lauderdale", "Madison", "McNairy", "Obion",
                 "Shelby", "Tipton", "Weakley")
    ),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = NA_character_
  ),

  GA = list(
    name = "Georgia",
    fips = "13",
    crs = 32617,
    region_map = function() make_cluster_region_map("13", 32617, 5, label_georgia_clusters),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = "County groups were generated reproducibly from county centroid k-means clusters."
  ),

  MN = list(
    name = "Minnesota",
    fips = "27",
    crs = 32615,
    region_map = function() make_cluster_region_map("27", 32615, 4, label_minnesota_clusters),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = "County groups were generated reproducibly from county centroid k-means clusters."
  ),

  CA = list(
    name = "California",
    fips = "06",
    crs = 32610,
    region_map = function() make_cluster_region_map("06", 32610, 5, label_california_clusters),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = "County groups were generated reproducibly from county centroid k-means clusters."
  ),

  CO = list(
    name = "Colorado",
    fips = "08",
    crs = 32613,
    region_map = list(
      East                    = c("Alamosa", "Baca", "Bent", "Chaffee", "Cheyenne",
                                  "Conejos", "Costilla", "Crowley", "Custer", "Huerfano",
                                  "Kiowa", "Kit Carson", "Las Animas", "Lincoln", "Logan",
                                  "Mineral", "Morgan", "Otero", "Phillips", "Prowers",
                                  "Rio Grande", "Saguache", "Sedgwick", "Washington", "Yuma"),
      `Front Range & Mountains` = c("Adams", "Arapahoe", "Boulder", "Broomfield",
                                    "Clear Creek", "Denver", "Douglas", "El Paso", "Elbert",
                                    "Fremont", "Gilpin", "Jefferson", "Lake", "Larimer",
                                    "Park", "Pueblo", "Teller", "Weld"),
      West                    = c("Archuleta", "Delta", "Dolores", "Eagle", "Garfield",
                                  "Grand", "Gunnison", "Hinsdale", "Jackson", "La Plata",
                                  "Mesa", "Moffat", "Montezuma", "Montrose", "Ouray",
                                  "Pitkin", "Rio Blanco", "Routt", "San Juan", "San Miguel",
                                  "Summit")
    ),
    manual_alpha_r = NA_real_,
    manual_alpha_l = NA_real_,
    manual_protocol = NA_character_
  )
)
