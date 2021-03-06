// util project util.go
package util

import (
	"crypto/md5"
	"crypto/rand"
	"errors"
	"fmt"
	"github.com/quiteawful/g0/conf"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"net/url"
	"os/exec"
	"regexp"
)

var (
	_util *ConfImg = nil
)

type ConfImg struct {
	Imagepath string
	Thumbpath string
}

func init() {
	if _util == nil {
		_util = new(ConfImg)
	}
	tmpConf := new(ConfImg)
	conf.Fill(tmpConf)

	_util.Imagepath = tmpConf.Imagepath
	_util.Thumbpath = tmpConf.Thumbpath
}

const MAX_SIZE = 10485760

var StdChars = []byte("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
var imageregex = regexp.MustCompile(`image\/(.+)|video\/webm`)

func DownloadImage(link string) (filename, hash string, errret error) {
	_, err := url.Parse(link)
	if err != nil {
		return "", "", err
	}
	var bufa [64]byte
	var b []byte
	var urlType []string
	var mime string

	size := 0
	buf := bufa[:]
	res, err := http.Get(link)
	if err != nil {
		return "", "", err
	}
	defer res.Body.Close()
	if err != nil {
		return "", "", err
	}
	for {
		n, err := res.Body.Read(buf)
		if size == 0 {
			mime = http.DetectContentType(buf)
			urlType = imageregex.FindStringSubmatch(mime)
			if urlType == nil {
				return "", "", fmt.Errorf("not an image: %q", mime)
			}
		}
		size += n
		if size > MAX_SIZE {
			return "", "", fmt.Errorf("image too large")
		}
		b = append(b, buf[:n]...)
		if err == io.EOF {
			h := md5.New()
			h.Write(b)
			if urlType[1] == "" {
				urlType[1] = "webm"
			}
			filename = newLenChars(6, StdChars) + "." + urlType[1]
			ioutil.WriteFile(_util.Imagepath+filename, b, 0644)
			if mime == "video/webm" {
				out, err := exec.Command("ffmpeg", "-y", "-i", _util.Imagepath+filename, "-ss", "2", "-vframes", "1", _util.Imagepath+"tmp.jpeg").CombinedOutput()
				if err != nil {
					fmt.Println(err.Error() + string(out))
				}
			}
			return filename, fmt.Sprintf("%x", h.Sum(nil)), nil
		}
	}
	return filename, "", nil
}

// NewLenChars stolen from https://github.com/dchest/uniuri , thx
func newLenChars(length int, chars []byte) string {
	b := make([]byte, length)
	r := make([]byte, length+(length/4)) // storage for random bytes.
	clen := byte(len(chars))
	maxrb := byte(256 - (256 % len(chars)))
	i := 0
	for {
		if _, err := io.ReadFull(rand.Reader, r); err != nil {
			panic("error reading from random source: " + err.Error())
		}
		for _, c := range r {
			if c >= maxrb {
				continue
			}
			b[i] = chars[c%clen]
			i++
			if i == length {
				return string(b)
			}
		}
	}
	panic("unreachable")
}

func IsDirWriteable(path string) bool {
	// can be used for setup/startup to check wether we can write to imagepath.
	return false
}

func DownloadPage(link string) (string, error) {
	if link == "" {
		err := errors.New("Empty url.")
		log.Printf("Util.DownloadPage: %s\n", err.Error())
		return "", err
	}

	resp, err := http.Get(link)
	if err != nil {
		log.Printf("Util.DownloadPage: %s\n", err.Error())
		return "", err
	}
	defer resp.Body.Close()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Printf("Util.DownloadPage: %s\n", err.Error())
		return "", err
	}

	return string(body), nil
}
