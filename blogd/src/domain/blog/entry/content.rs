use uuid::Uuid;

use blogir::Section;

#[derive(Debug, Clone, Copy, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub struct EntryContentId(Uuid);

pub struct EntryContent {
    id: EntryContentId,
    sections: Vec<Section>,
}
