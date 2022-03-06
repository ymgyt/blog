use blogd::gql;

#[tokio::main]
async fn main() -> Result<(), anyhow::Error> {
    let schema = gql::build_schema().finish();

    println!("{}", schema.sdl());

    Ok(())
}
