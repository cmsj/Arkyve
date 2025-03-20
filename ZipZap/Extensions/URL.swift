//
//  URL.swift
//  ZipZap
//
//  Created by Chris Jones on 20/03/2025.
//

extension URL {
    func relativeTo(_ base: URL? = nil) -> String {
        // FIXME: Can we just do this instead?
//        return self.pathComponents.subtractPath(base?.pathComponents ?? []).joined("/")
        let absolutePath = self.path
        var pwdPath = base?.path ?? ""
        if pwdPath.last != "/" {
            pwdPath += "/"
        }
        return absolutePath.deletingPrefix(pwdPath)
    }
}
