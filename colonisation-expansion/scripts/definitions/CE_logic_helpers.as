class NextIndex {
    uint index = 0;

    uint next(uint listSize) {
        if (listSize == 0) {
            throw("Cannot iterate through an empty list");
        }
        uint nextIndex = (index + 1) % listSize;
        index = nextIndex;
        return nextIndex;
    }

    void save(SaveFile& file) {
        file << index;
    }

    void load(SaveFile& file) {
        file >> index;
    }
}
