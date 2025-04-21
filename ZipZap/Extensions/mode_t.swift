//
//  mode_t.swift
//  ZipZap
//
//  Created by Chris Jones on 03/03/2025.
//
import Darwin.sys

extension mode_t {
    static var directory: mode_t {
        S_IFDIR | S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH
    }

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
            case 0:
                output += "-"
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
            case 0:
                output += "-"
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
            case 0:
                output += "-"
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
}
