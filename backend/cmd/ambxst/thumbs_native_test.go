package main

import (
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestScaleCenterCrop(t *testing.T) {
	src := image.NewRGBA(image.Rect(0, 0, 400, 200))
	out := scaleCenterCrop(src, 64)
	b := out.Bounds()
	if b.Dx() != 64 || b.Dy() != 64 {
		t.Fatalf("expected 64x64, got %dx%d", b.Dx(), b.Dy())
	}
}

func TestGenerateThumbImage(t *testing.T) {
	dir := t.TempDir()
	srcPath := filepath.Join(dir, "in.png")

	img := image.NewRGBA(image.Rect(0, 0, 100, 50))
	for y := 0; y < 50; y++ {
		for x := 0; x < 100; x++ {
			img.Set(x, y, color.RGBA{R: uint8(x * 2), G: uint8(y * 4), B: 90, A: 255})
		}
	}
	f, err := os.Create(srcPath)
	if err != nil {
		t.Fatal(err)
	}
	if err := png.Encode(f, img); err != nil {
		t.Fatal(err)
	}
	f.Close()

	thumbPath := filepath.Join(dir, "in.png.jpg")
	if err := generateThumbImage(srcPath, thumbPath, 32); err != nil {
		t.Fatalf("generateThumbImage: %v", err)
	}

	tf, err := os.Open(thumbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer tf.Close()

	decoded, err := jpeg.Decode(tf)
	if err != nil {
		t.Fatalf("thumb not valid jpeg: %v", err)
	}
	bounds := decoded.Bounds()
	if bounds.Dx() != 32 || bounds.Dy() != 32 {
		t.Fatalf("expected 32x32 thumb, got %dx%d", bounds.Dx(), bounds.Dy())
	}
}

func TestGenerateThumbSVG(t *testing.T) {
	if _, err := exec.LookPath("rsvg-convert"); err != nil {
		t.Skip("rsvg-convert is not installed")
	}

	dir := t.TempDir()
	srcPath := filepath.Join(dir, "vector.svg")
	svg := `<svg xmlns="http://www.w3.org/2000/svg" width="96" height="48" viewBox="0 0 96 48">
  <rect width="96" height="48" fill="#4169e1"/>
</svg>`
	if err := os.WriteFile(srcPath, []byte(svg), 0o644); err != nil {
		t.Fatal(err)
	}

	thumbPath := filepath.Join(dir, "vector.svg.jpg")
	if err := generateThumb(srcPath, thumbPath, 32); err != nil {
		t.Fatalf("generateThumb SVG: %v", err)
	}

	tf, err := os.Open(thumbPath)
	if err != nil {
		t.Fatal(err)
	}
	defer tf.Close()

	decoded, err := jpeg.Decode(tf)
	if err != nil {
		t.Fatalf("SVG thumbnail is not a valid JPEG: %v", err)
	}
	bounds := decoded.Bounds()
	if bounds.Dx() != 32 || bounds.Dy() != 32 {
		t.Fatalf("expected 32x32 SVG thumb, got %dx%d", bounds.Dx(), bounds.Dy())
	}
}

