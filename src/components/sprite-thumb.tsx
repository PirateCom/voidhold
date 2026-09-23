import atlas from "../../public/sprites/ogame.json";

const SHEET = "/sprites/ogame_sprite.jpg";
const SPRITE_SIZE = 96;

type AtlasSprite = {
  id: string;
  x: number | null;
  y: number | null;
  w: number | null;
  h: number | null;
};

export function SpriteThumb({ id }: { id: string }) {
  const sprite = (atlas.sprites as AtlasSprite[]).find((entry) => entry.id === id);
  if (
    !sprite ||
    sprite.x == null ||
    sprite.y == null ||
    sprite.w == null ||
    sprite.h == null ||
    sprite.w <= 0 ||
    sprite.h <= 0
  ) {
    return null;
  }
  const scale = SPRITE_SIZE / sprite.w;
  return (
    <div
      className="relative shrink-0 overflow-hidden rounded-xl border border-[var(--border)] bg-black/40"
      style={{ width: SPRITE_SIZE, height: Math.round(SPRITE_SIZE * (sprite.h / sprite.w)) }}
    >
      <div
        aria-hidden
        className="absolute top-0 left-0"
        style={{
          width: sprite.w,
          height: sprite.h,
          backgroundImage: `url(${SHEET})`,
          backgroundRepeat: "no-repeat",
          backgroundPosition: `-${sprite.x}px -${sprite.y}px`,
          transform: `scale(${scale})`,
          transformOrigin: "top left",
        }}
      />
    </div>
  );
}
