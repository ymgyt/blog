#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    println!("{}", blogd::print_sdl());

    Ok(())
}
