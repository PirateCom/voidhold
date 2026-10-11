import atlas from "../../public/sprites/ogame.json";

const SHEET = "/sprites/ogame_sprite.jpg";
const SPRITE_SIZE = 96;

/** New art in public/img — mines, power, storage, facilities, defences. */
const FILE_SPRITES: Record<string, string> = {
  ore_mine: "/img/mine/ore_mine.jpg",
  crystal_mine: "/img/mine/crystal_mine.jpg",
  deuterium_extractor: "/img/mine/deut_mine.jpg",
  power_plant: "/img/power/power_plant.jpg",
  fusion_reactor: "/img/power/fusion_reactor.jpg",
  ore_storage: "/img/storage/ore_storage.jpg",
  crystal_storage: "/img/storage/crystal_storage.jpg",
  deuterium_storage: "/img/storage/deut_storage.jpg",
  robotics_factory: "/img/facilities/robotics_factory.jpg",
  shipyard: "/img/facilities/shipyard.jpg",
  research_lab: "/img/facilities/research_lab.jpg",
  missile_silo: "/img/facilities/missle_silo.jpg",
  nanite_factory: "/img/facilities/nanite_fctory.jpg",
  terraformer: "/img/facilities/terraformer.jpg",
  rocket_launcher: "/img/defences/rocketlauncher.jpg",
  light_laser: "/img/defences/lightlaser.jpg",
  heavy_laser: "/img/defences/heavylaser.jpg",
  gauss_cannon: "/img/defences/gaussiancannon.jpg",
  ion_cannon: "/img/defences/ioncannon.jpg",
  plasma_turret: "/img/defences/plasmaturret.jpg",
  small_shield_dome: "/img/defences/small dome.jpg",
  large_shield_dome: "/img/defences/large dome.jpg",
  antiballistic_missile: "/img/defences/antiballistic missle.jpg",
  interplanetary_missile: "/img/defences/interplanetary missle.jpg",
};

type AtlasSprite = {
  id: string;
  x: number | null;
  y: number | null;
  w: number | null;
  h: number | null;
};

export function SpriteThumb({ id }: { id: string }) {
  const file = FILE_SPRITES[id];
  if (file) {
    return (
      <div
        className="relative shrink-0 overflow-hidden rounded-xl border border-[var(--border)] bg-black/40"
        style={{ width: SPRITE_SIZE, height: SPRITE_SIZE }}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img src={encodeURI(file)} alt="" className="h-full w-full object-cover" />
      </div>
    );
  }

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
    return (
      <div
        className="flex shrink-0 items-center justify-center rounded-xl border border-[var(--border)] bg-black/40 px-2 text-center text-[10px] uppercase tracking-wide text-[var(--muted-fg)]"
        style={{ width: SPRITE_SIZE, height: SPRITE_SIZE }}
      >
        {id.replace(/_/g, " ")}
      </div>
    );
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
