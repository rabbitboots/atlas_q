**NOTE:** This is a beta. All ArrayImage code is untested.

# AtlasQ

AtlasQ is a [quadtree](https://en.wikipedia.org/wiki/Quadtree)-based texture atlas library for the [LÖVE](https://love2d.org/) framework.

The intended use case is for SpriteBatch rendering, where the atlas might need small updates at run-time (probably during loading screens: it hasn't been tested in a real game with actual gameplay yet).

The sub-textures would be spritesheets and tilesets with power-of-two dimensions. The atlas can grow by placing all existing nodes into the upper-left quadrant of a new root node, and copying the pixel data to a new ImageData + texture pair with larger dimensions.

Two atlas types are provided: one with a single 2D image, and one that uses an [ArrayImage](https://love2d.org/wiki/love.graphics.newArrayImage) with multiple slices.


# API: Texture Type: 2D

## atlasQ.newAtlas

Creates an atlas object.

`local atlas = atlasQ.newAtlas(w, h, pixel_format, tex_settings)`

* `w`: Starting width of the atlas in pixels. Must be a power of two, and cannot be larger than the system's max texture size.
* `h`: Starting height of the atlas in pixels. Must be a power of two.
* `pixel_format`: (Optional) The LÖVE [PixelFormat](https://love2d.org/wiki/PixelFormat) to use for the atlas ImageData and resulting texture.
* `tex_settings`: (Optional) The settings table to use with [love.graphics.newImage()](https://love2d.org/wiki/love.graphics.newImage).

**Returns:** A new atlas object.


## atlas:addImageData

Try to add the contents of an ImageData to the atlas. If successful, the ImageData is pasted into the texture, and you can use the returned `node.x` and `node.y` as offsets to get the image contents.

`local node = atlas:addImageData(i_data)`

* `i_data`: The LÖVE ImageData to add to the atlas.

**Returns:** The occupied node on success, or `false` if a suitable node could not be found.

**Notes:** Call `atlas:refreshTexture()` after successful changes to upload the new pixel data to the texture.


## atlas:refreshTexture

Updates the atlas texture's pixel data. Call after making changes with `atlas:addImageData`.

`atlas:refreshTexture()`


## atlas:patchTexture

Updates the atlas texture's pixel data for *one node*. Call after making a single change with `atlas:addImageData`.

`atlas:patchTexture(i_data, node)`

* `i_data`: The ImageData which was just added with `atlas:addImageData`.
* `node`: The node returned by `atlas:addImageData`.


## atlas:enlarge()

Try to enlarge the atlas by doubling its width and height.

`local success = atlas:enlarge()`

**Returns:** `true` on success, `false` if the atlas texture would exceed the [system max texture size](https://love2d.org/wiki/GraphicsLimit).


# API: Texture Type: ArrayImage


## atlasQ.newArrayAtlas

Creates a new atlas with an ArrayImage.

`local array_atlas = atlasQ.newArrayAtlas(n_slices, w, h, pixel_format, tex_settings)`

* `n_slices`: Starting number of image slices in the atlas ArrayImage. Cannot be larger than the system's max *texturelayers*.
* `w`: Starting width of the atlas in pixels. Must be a power of two, and cannot be larger than the system's max *texturesize*.
* `h`: Starting height of the atlas in pixels. Must be a power of two, and cannot be larger than the system's max *texturesize*.
* `pixel_format`: (Optional) The LÖVE [PixelFormat](https://love2d.org/wiki/PixelFormat) to use for the atlas ImageData and resulting ArrayImage.
* `tex_settings`: (Optional) The settings table to use with [love.graphics.newImage](https://love2d.org/wiki/love.graphics.newImage).

**Returns:** A new array atlas object.


## array_atlas:addImageData

Try to add the contents of an ImageData to the array atlas. If successful, the ImageData is pasted into the texture slice, and you can use the returned `node.x` and `node.y` as offsets to get the image contents.

`local node = array_atlas:addImageData(slice_n, i_data)`

* `slice_n`: The quadtree and slice index to use.
* `i_data`: The LÖVE ImageData to add to the slice.

**Returns:** The occupied node on success, or `false` if a suitable node could not be found.

**Notes:** Call `array_atlas:refreshTexture()` after successful changes to upload the new pixel data to the texture.


## array_atlas:refreshTexture

Updates the atlas ArrayImage's pixel data. Call after making changes with `array_atlas:addImageData`.

`array_atlas:refreshTexture()`


## array_atlas:patchTexture

Updates the atlas ArrayImage's pixel data for *one node in one slice*. Call after making a single change with `array_atlas:addImageData`.

`array_atlas:patchTexture(i_data, node, slice_n)`

* `i_data`: The ImageData which was just added with `atlas:addImageData`.
* `node`: The node returned by `atlas:addImageData`.
* `slice_n`: The slice index to update.


## array_atlas:enlarge

Try to enlarge the array atlas by doubling its width and height.

`local success = array_atlas:enlarge()`

**Returns:** `true` on success, `false` if the array atlas texture would exceed the system's max *texturesize*.


## array_atlas:addSlices

Try to add more slices to the array atlas's ArrayImage.

`local success = array_atlas:addSlices(count)`

* `count`: The number of slices to try adding.

**Returns:** `true` on success, `false` if the new slice count would exceed th system's max *texturelayers*.


# Usage Notes

## Texture continuity

The act of enlarging an atlas or giving it more array slices causes a *new* texture to be created internally. Any SpriteBatches which use this texture should be updated to reference the new texture.

Do something like this after a successful call to `enlarge()` or `addSlices()`, and before the next batch draw:

```lua
if sprite_batch:getTexture() ~= atlas.tex then
	sprite_batch:setTexture(atlas.tex)
	-- Clear and re-add all sprites.
end
```

Likewise, if you used the texture as a shader variable, that needs to be updated as well.

AtlasQ passes the following settings from the old texture to the new one:
* Wrap state
* Texture filter state
* Mipmap Filter state

Additionally, the texture `settings` table passed in `atlasQ.newAtlas()` is stored in `atlas.tex_settings`, and will be used when creating the new texture.


# MIT License

MIT License

Copyright (c) 2023 RBTS

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
