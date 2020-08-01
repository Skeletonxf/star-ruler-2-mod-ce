// Very surprised the only map like datastructure in AngelScript's standard
// library is a key value dictionary with only strings permitted for the keys

export ArrayMap;

/**
 * An integer -> integer map.
 */
tidy final class ArrayMap {
    // These two arrays are kept in sync by the methods, such that
    // each index refers to the associatd key/value pair.
    array<int> keys;
    array<int> values;

    /**
     * Returns the number of elements in this map.
     */
    uint length() {
        return keys.length;
    }

    /**
     * Adds or updates a key value pair.
     */
    void set(int key, int value) {
        for (uint i = 0, cnt = length(); i < cnt; ++i) {
            if (keys[i] == key) {
                // update existing entry
                values[i] = value;
                return;
            }
        }
        // add new entry
        keys.insertLast(key);
        values.insertLast(value);
    }

    /**
     * Checks for a matching key
     */
    bool has(int key) {
        for (uint i = 0, cnt = length(); i < cnt; ++i) {
            if (keys[i] == key) {
                return true;
            }
        }
        return false;
    }

    /**
     * Returns the value associated with a key, or throws an exception
     * if there is no matching key.
     */
    int get(int key) {
        for (uint i = 0, cnt = length(); i < cnt; ++i) {
            if (keys[i] == key) {
                return values[i];
            }
        }
        throw("Key does not exist");
        return 0;
    }

    /**
     * Increments a key's value by 1, setting the value to 1 if it was not present.
     */
    void increment(int key) {
        if (has(key)) {
            set(key, get(key) + 1);
        } else {
            set(key, 1);
        }
    }
}
