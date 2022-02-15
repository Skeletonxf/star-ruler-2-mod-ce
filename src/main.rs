use serde::Deserialize;
use std::error::Error;
use std::fmt::Display;
use std::fs;
use std::path::PathBuf;
use std::fs::ReadDir;

fn main() {
    std::process::exit(match check_design_files() {
        Ok(_) => 0,
        Err(error) => {
            eprintln!("Error scanning design files: {}", error);
            1
        }
    })
}

const EXPECTED_DESIGN_HULL_NAMES: [&str; 13] = [
   "$1Station",
   "$1FlagTiny",
   "$1FlagSmall",
   "$1FlagMedium",
   "$1FlagLarge",
   "$1FlagVeryLarge",
   "$1FlagHuge",
   "$1Satellite",
   "$1Tiny",
   "$1Small",
   "$1Medium",
   "$1Large",
   "TyrantBattleship",
];

fn check_design_files() -> Result<(), Box<dyn Error>> {
    check_design_folder(fs::read_dir("colonisation-expansion/data/designs")?)?;
    Ok(())
}

fn check_design_folder(from: ReadDir) -> Result<(), Box<dyn Error>> {
    for entry in from {
        let entry = entry?;
        let path = entry.path();
        println!("Scanning {:?}", path);
        if path.is_file() {
            let filepath = path.clone();
            let design_json_file_str = String::from_utf8(fs::read(path)?)?;
            let parsed: SR2DesignFile = serde_json::from_str(&design_json_file_str)?;
            if !EXPECTED_DESIGN_HULL_NAMES.iter().any(|&name| name == parsed.hull) {
                return Err(Box::new(InvalidDesignHullName {
                    hull: parsed.hull.to_string(),
                    filepath,
                }));
            }
        } else {
            check_design_folder(fs::read_dir(path)?)?;
        }
    }
    Ok(())
}

#[derive(Deserialize, Debug)]
struct SR2DesignFile<'a> {
    hull: &'a str,
}

#[derive(Debug)]
struct InvalidDesignHullName {
    filepath: PathBuf,
    hull: String,
}

impl Display for InvalidDesignHullName {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Hull name in design file {:?} is not likely to be valid: {}", self.filepath, self.hull)
    }
}

impl<'a> Error for InvalidDesignHullName {}
