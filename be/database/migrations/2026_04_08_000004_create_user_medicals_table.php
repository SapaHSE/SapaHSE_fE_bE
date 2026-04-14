<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('user_medicals', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->uuid('user_id');

            // ── Identitas pemeriksaan ────────────────────────────────
            $table->string('title', 200)->nullable();          // e.g. "Medical Check-Up Tahunan 2026"
            $table->string('patient_name', 150)->nullable();   // nama pasien

            // ── Tanggal ──────────────────────────────────────────────
            $table->date('checkup_date')->nullable();
            $table->date('next_checkup_date')->nullable();

            // ── Data fisik ───────────────────────────────────────────
            $table->string('blood_type', 10)->nullable();      // e.g. "A+"
            $table->string('height', 20)->nullable();          // e.g. "168 cm"
            $table->string('weight', 20)->nullable();          // e.g. "65 kg"
            $table->string('blood_pressure', 20)->nullable();  // e.g. "120/80 mmHg"
            $table->string('allergies')->nullable();

            // ── Hasil pemeriksaan ────────────────────────────────────
            $table->string('result', 100)->nullable();         // "Fit to Work" | "Fit with Limitation" | "Not Fit to Work"

            // ── Dokter & fasilitas ────────────────────────────────────
            $table->string('doctor_name', 150)->nullable();    // e.g. "dr. Andi Wijaya, Sp.OK"
            $table->string('doctor_contact', 50)->nullable();  // e.g. "0812-3333-4444"
            $table->string('facility_name', 200)->nullable();  // e.g. "Klinik Pratama BBE"
            $table->string('facility_contact', 50)->nullable();// e.g. "0541-123456"

            // ── Catatan & checklist ───────────────────────────────────
            $table->text('doctor_notes')->nullable();
            $table->json('checklist_items')->nullable();       // [{label, done}, ...]

            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->cascadeOnDelete();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('user_medicals');
    }
};