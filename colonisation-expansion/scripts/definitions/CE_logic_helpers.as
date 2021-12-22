class NextIndex {
    uint index = 0;

    uint next(uint listSize) {
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
