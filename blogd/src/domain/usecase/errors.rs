use std::io;

#[derive(thiserror::Error, Debug)]
pub enum UsecaseError<E> {
    #[error("io error: {0}")]
    Io(#[from] io::Error),
    #[error(transparent)]
    Variant(E),
}
