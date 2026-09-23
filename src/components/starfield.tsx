"use client";

import { useEffect, useRef } from "react";

type Star = { x: number; y: number; radius: number; speed: number; alpha: number };

export function Starfield() {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const surface = ref.current;
    const paint = surface?.getContext("2d") ?? null;
    if (!surface || !paint) return;
    const stars: Star[] = [];
    let frame = 0;
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    function resize() {
      const parent = surface?.parentElement;
      if (!surface || !parent) return;
      surface.width = parent.clientWidth;
      surface.height = parent.clientHeight;
      stars.length = 0;
      for (let i = 0; i < 60; i++) {
        stars.push({
          x: Math.random() * surface.width,
          y: Math.random() * surface.height,
          radius: Math.random() * 1.2 + 0.4,
          speed: Math.random() * 0.35 + 0.05,
          alpha: Math.random() * 0.8 + 0.2,
        });
      }
    }

    function draw() {
      if (!surface || !paint) return;
      paint.clearRect(0, 0, surface.width, surface.height);
      for (const star of stars) {
        paint.fillStyle = `rgba(0, 240, 255, ${star.alpha})`;
        paint.beginPath();
        paint.arc(star.x, star.y, star.radius, 0, Math.PI * 2);
        paint.fill();
        if (!reduced) {
          star.y += star.speed;
          if (star.y > surface.height) {
            star.y = 0;
            star.x = Math.random() * surface.width;
          }
        }
      }
      frame = requestAnimationFrame(draw);
    }

    resize();
    draw();
    window.addEventListener("resize", resize);
    return () => {
      cancelAnimationFrame(frame);
      window.removeEventListener("resize", resize);
    };
  }, []);

  return <canvas ref={ref} className="pointer-events-none absolute inset-0 z-0 h-full w-full opacity-60" aria-hidden />;
}
