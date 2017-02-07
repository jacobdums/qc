module QC
  module Utils
    def cat_fastq_files outf, *fnames
      File.open(outf, "w") do |f|
        fnames.each do |fname|
          AbortIf.logger.debug { "Writing #{fname} to #{outf}" }

          FastqFile.open(fname).each_record_fast do |head, seq, desc, qual|
            f.puts "@#{head}\n#{seq}\n+#{desc}\n#{qual}"
          end
        end
      end
    end

    def check_files *fnames
      fnames.each do |fname|
        abort_unless_file_exists fname
      end
    end

    def eputs msg=""
      $stderr.puts msg
    end

    def seqcount fname
      if fname.match(/.gz$/)
        num_seqs = (`gunzip -c #{fname} | wc -l`.to_f / 4).round
      else
        num_seqs = (`wc -l #{fname}`.to_f / 4).round
      end

      num_seqs
    end

    def qual_trim_se!(inf:, out:, log:)
      count = seqcount inf
      if count >= 1
        cmd = "java -jar #{TRIMMO} SE " +
              "-threads #{THREADS} " +
              "#{inf} " +
              "#{out} " +
              "SLIDINGWINDOW:#{WINDOW_SIZE}:#{QUAL} " +
              "MINLEN:#{MIN_LEN} " +
              ">> #{log} 2>&1"

        Process.run_it! cmd
      else
        AbortIf.logger.warn { "No reads in #{inf}. Not running " +
                              "qual_trim_se!()" }

        # Make a empty placeholder file
        Process.run_it! "touch #{out}"

        AbortIf.logger.info { "Made fake file #{out}" }
      end

      Process.run_it "rm #{inf}"

      out
    end

    def qual_trim_pe! in1:, in2:, baseout:, log:
                         cmd = "java -jar #{TRIMMO} PE " +
                               "-threads #{THREADS} " +
                               "#{in1} " +
                               "#{in2} " +
                               "-baseout #{baseout} " +
                               "SLIDINGWINDOW:#{WINDOW_SIZE}:#{QUAL} " +
                               "MINLEN:#{MIN_LEN} " +
                               ">> #{log} 2>&1"

      Process.run_it! cmd
      Process.run_it "rm #{in1} #{in2}"
    end

    def flash! in1:, in2:, outdir:, log:
                  cmd = "#{FLASH} " +
                        "--threads #{THREADS} " +
                        "--output-prefix flashed " +
                        "--max-overlap #{MAX_OVERLAP} " +
                        "#{in1} " +
                        "#{in2} " +
                        "--output-directory #{outdir} " +
                        ">> #{log} 2>&1"

      Process.run_it! cmd
      Process.run_it "rm #{in1} #{in2}"
      Process.run_it!("mv #{outdir}/flashed.extendedFrags.fastq " +
                      "#{outdir}/../reads.adapter_trimmed.flash_combined")
      Process.run_it!("mv #{outdir}/flashed.notCombined_1.fastq " +
                      "#{outdir}/../reads.adapter_trimmed.flash_notcombined_1P")
      Process.run_it!("mv #{outdir}/flashed.notCombined_2.fastq " +
                      "#{outdir}/../reads.adapter_trimmed.flash_notcombined_2P")
    end

    def adapter_trim!(in1:, in2:, baseout:, log:)
      # Trim the adapters
      cmd = "java -jar #{TRIMMO} PE " +
            "-threads #{THREADS} " +
            "-baseout #{baseout} " +
            "#{in1} " +
            "#{in2} " +
            "ILLUMINACLIP:" +
            "#{TRIMSEQS}:" +
            "#{SEED_MISMATCHES}:" +
            "#{PALINDROME_CLIP_THRESHOLD}:" +
            "#{SIMPLE_CLIP_THRESHOLD} " +
            ">> #{log} 2>&1"

      Process.run_it! cmd
    end

    def screen!(index:, reads:, log:)
      # use bowtie2 to screen reads against against a genome
      good_reads = reads + ".did_not_align.fq"
      bad_reads  = reads + ".did_align.fq"

      cmd = "#{BOWTIE} -x #{index} " +
            "-U #{reads} " +
            "--sensitive --end-to-end " +
            "--threads #{THREADS} " +
            "--un #{good_reads} " +
            "--al #{bad_reads} " +
            "-S /dev/null " +
            ">> #{log} 2>&1"

      Process.run_it! cmd

      [good_reads, bad_reads]
    end

    def fix_pairs!(in1:, in2:, outdir:, log:)
      basename = File.join outdir, "ryanapplehehe"

      cmd = "#{FIX_PAIRS} #{in1} #{in2} #{basename} " +
            ">> #{log} 2>&1"

      Process.run_it! cmd

      out1 = basename + ".1.fq"
      out2 = basename + ".2.fq"
      outU = basename + ".U.fq"

      [out1, out2, outU]
    end
  end
end
