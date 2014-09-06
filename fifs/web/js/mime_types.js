var mimeTypes= {
  ".txt": "text/plain",
  ".rtf": "application/rtf",
  ".rtx": "text/richtext",

  ".pdf": "appliation/pdf", ".css": "text/css",
  ".csv": "text/csv",
  ".json": "application/json",
  ".doc": "application/msword",
  ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ".xls": "application/vnd.ms-excel",
  ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",

  ".bmp": "image/bmp",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",

  ".zip": "application/zip",
  ".rar": "application/x-rar-compressed",
}

function getMIMEType(filename) {
    var re = /\..+$/;
    var ext = filename.match(re);
    return mimeTypes[ext];
}
