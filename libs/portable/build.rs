fn main() {
    #[cfg(windows)]
    {
        use std::io::Write;
        let mut res = winres::WindowsResource::new();
        res.set_icon("../../res/icon.ico")
            .set_language(winapi::um::winnt::MAKELANGID(
                winapi::um::winnt::LANG_ENGLISH,
                winapi::um::winnt::SUBLANG_ENGLISH_US,
            ))
            .set_manifest_file("../../res/manifest.xml");
        set_opmd_version(&mut res);
        match res.compile() {
            Err(e) => {
                write!(std::io::stderr(), "{}", e).unwrap();
                std::process::exit(1);
            }
            Ok(_) => {}
        }
    }
}

// The release workflow sets OPMD_VERSION from the opmd-vX.Y.Z tag; without it the setup exe keeps the crate version.
#[cfg(windows)]
fn set_opmd_version(res: &mut winres::WindowsResource) {
    println!("cargo:rerun-if-env-changed=OPMD_VERSION");
    let Ok(version) = std::env::var("OPMD_VERSION") else {
        return;
    };
    res.set("FileVersion", &version).set("ProductVersion", &version);
    let numbers: Vec<u64> = version
        .split(|c| c == '.' || c == '-')
        .take(3)
        .map_while(|n| n.parse().ok())
        .collect();
    if let [major, minor, patch] = numbers[..] {
        let packed = major << 48 | minor << 32 | patch << 16;
        res.set_version_info(winres::VersionInfo::FILEVERSION, packed)
            .set_version_info(winres::VersionInfo::PRODUCTVERSION, packed);
    }
}
