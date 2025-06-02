//
//  mode_t.swift
//  Arkyve
//
//  Created by Chris Jones on 03/03/2025.
//
import Darwin.sys

extension mode_t {
    static let directory: mode_t = 0 | S_IFDIR | S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH

    var string: String {
        get {
            var output = ""

            // Type
            switch (self & S_IFMT) {
            case S_IFDIR:            /* directory */
               output += "d"
            case S_IFCHR:            /* character special */
                output += "c"
            case S_IFBLK:            /* block special */
                output += "b"
            case S_IFREG:            /* regular */
                output += "-"
            case S_IFLNK:            /* symbolic link */
                output += "l"
            case S_IFSOCK:            /* socket */
                output += "s"
            case S_IFIFO:            /* fifo */
                output += "p"
            default:            /* unknown */
                output += "?"
            }

            // User
            if (self & S_IRUSR != 0) {
                output += "r"
            } else {
                output += "-"
            }
            if (self & S_IWUSR != 0 ) {
                output += "w"
            } else {
                output += "-"
            }
            switch (self & (S_IXUSR | S_ISUID)) {
            case S_IXUSR:
                output += "x"
            case S_ISUID:
                output += "S"
            case S_IXUSR | S_ISUID:
                output += "s"
            default:
                output += "-"
            }

            // Group
            if (self & S_IRGRP != 0) {
                output += "r"
            } else {
                output += "-"
            }
            if (self & S_IWGRP != 0 ) {
                output += "w"
            } else {
                output += "-"
            }
            switch (self & (S_IXGRP | S_ISGID)) {
            case S_IXGRP:
                output += "x"
            case S_ISGID:
                output += "S"
            case S_IXGRP | S_ISGID:
                output += "s"
            default:
                output += "-"
            }

            // Other
            if (self & S_IROTH != 0) {
                output += "r"
            } else {
                output += "-"
            }
            if (self & S_IWOTH != 0 ) {
                output += "w"
            } else {
                output += "-"
            }
            switch (self & (S_IXOTH | S_ISVTX)) {
            case S_IXOTH:
                output += "x"
            case S_ISVTX:
                output += "S"
            case S_IXOTH | S_ISVTX:
                output += "s"
            default:
                output += "-"
            }

            return output
        }
    }

    var accessibilityString: String {
        get {
            var output = ""

            output +=   "User: \(self.IRUSR ? "read" : "no read"), \(self.IWUSR ? " write" : "no write"), \(self.IXUSR ? " execute" : "no execute"), \(self.ISUSR ? "SetUID" : "no SetUID")."
            output += " Group: \(self.IRGRP ? "read" : "no read"), \(self.IWGRP ? " write" : "no write"), \(self.IXGRP ? " execute" : "no execute"), \(self.ISGRP ? "SetGID" : "no SetGID")."
            output += " Other: \(self.IROTH ? "read" : "no read"), \(self.IWOTH ? " write" : "no write"), \(self.IXOTH ? " execute" : "no execute"), \(self.ISVTX ? "sticky" : "no sticky")"

            return output
        }
    }

    func getFlag(_ flag: mode_t) -> Bool {
        (self & flag != 0)
    }

    mutating func setFlag(_ flag: mode_t, _ value: Bool) {
        self = value ? self | flag : self & ~flag
    }

    var IRUSR: Bool {
        get { self.getFlag(S_IRUSR) }
        set { self.setFlag(S_IRUSR, newValue) }
    }
    var IWUSR: Bool {
        get { self.getFlag(S_IWUSR) }
        set { self.setFlag(S_IWUSR, newValue) }
    }
    var IXUSR: Bool {
        get { self.getFlag(S_IXUSR) }
        set { self.setFlag(S_IXUSR, newValue) }
    }
    var ISUSR: Bool {
        get { self.getFlag(S_ISUID) }
        set { self.setFlag(S_ISUID, newValue) }
    }

    var IRGRP: Bool {
        get { self.getFlag(S_IRGRP) }
        set { self.setFlag(S_IRGRP, newValue) }
    }
    var IWGRP: Bool {
        get { self.getFlag(S_IWGRP) }
        set { self.setFlag(S_IWGRP, newValue) }
    }
    var IXGRP: Bool {
        get { self.getFlag(S_IXGRP) }
        set { self.setFlag(S_IXGRP, newValue) }
    }
    var ISGRP: Bool {
        get { self.getFlag(S_ISGID) }
        set { self.setFlag(S_ISGID, newValue) }
    }

    var IROTH: Bool {
        get { self.getFlag(S_IROTH) }
        set { self.setFlag(S_IROTH, newValue) }
    }
    var IWOTH: Bool {
        get { self.getFlag(S_IWOTH) }
        set { self.setFlag(S_IWOTH, newValue) }
    }
    var IXOTH: Bool {
        get { self.getFlag(S_IXOTH) }
        set { self.setFlag(S_IXOTH, newValue) }
    }

    var ISVTX: Bool {
        get { self.getFlag(S_ISVTX) }
        set { self.setFlag(S_ISVTX, newValue) }
    }
}
