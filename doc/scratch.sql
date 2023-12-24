# chromosome
# add(6q)
# del(20q)
# t(12;22)
# t(8;9)


# der(1;21)
# dic(5;7) ?
# i(17q) ?
# ins(10;11) ?
# inv(16)
# r(7)


# gene
# mutation
#   amplification
#     amplification of
#     gain
#       gain of
#   rearrangement
#     rearrangement of
#   deletion
#     deletion of
#     loss of
#   translocation
#     translocation of
#   fusion

# gene
# mutation
#   amplification
#     amplification of
#     gain
#       gain of
#   rearrangement
#     rearrangement of
#   deletion
#     deletion of
#     loss of
#   translocation
#     translocation of
#   fusion




select
    pcf.genetic_abnormality_name
    , pcfn.normalization_name
    , pcfn.normalization_type
    , pcfn.gene_1
    , pcfn.gene_2
    , pcfn.match_token
    , pcf.id
from pathology_cases pc join pathology_case_findings pcf on pc.id = pcf.pathology_case_id
                        left join pathology_case_finding_normalizations pcfn on pcf.id = pcfn.pathology_case_finding_id
-- where pcf.genetic_abnormality_name like '%mutation%'
-- where   pc.accession_nbr_formatted  ='1-FI-19-0002556'
where pcf.genetic_abnormality_name != ':'
and lower(pcf.genetic_abnormality_name) != 'negative'
and lower(pcf.genetic_abnormality_name) != 'positive'
-- and pcf.genetic_abnormality_name like '%fusion%'
--  and pcf.genetic_abnormality_name = 'Gain of 5p15.2 with deletion of EGR1 (5q31)'

select
        pcf.genetic_abnormality_name
      , pcfn.normalization_name
	  , pcfn.normalization_type
	  , pcfn.gene_1
	  , pcfn.gene_2
	  , pcfn.match_token
	  , pcf.id
from pathology_cases pc join pathology_case_findings pcf on pc.id = pcf.pathology_case_id
                        left join pathology_case_finding_normalizations pcfn on pcf.id = pcfn.pathology_case_finding_id

-- where pcf.genetic_abnormality_name like '%mutation%'
-- where   pc.accession_nbr_formatted  ='1-FI-19-0002556'
where pcf.genetic_abnormality_name != ':'
and lower(pcf.genetic_abnormality_name) != 'negative'
and lower(pcf.genetic_abnormality_name) != 'positive'
-- and pcf.genetic_abnormality_name like '%fusion%'
--  and pcf.genetic_abnormality_name = 'Gain of 5p15.2 with deletion of EGR1 (5q31)'
and  pcf.id IN(
15,
 16,
 345,
 398,
 399,
 413,
 420,
 421,
 564,
 633,
 655,
 864,
 1024,
 1129,
 1131,
 1693,
 1855,
 1940,
 1959,
 2010,
 2069,
 2233,
 2326,
 2367,
 2478,
 2479,
 2772,
 2930,
 2935,
 3030,
 3032,
 3238,
 3239,
 3266,
 3507,
 3534,
 3758,
 3819,
 3955,
 4599,
 4685,
 4744,
 4877,
 4923,
 4968,
 5044,
 5210,
 5389,
 5542,
 5546,
 5651,
 5667,
 5668,
 5669,
 5709,
 5741,
 5869,
 5872,
 5875,
 5930,
 5969,
 6007,
 6282,
 6495,
 6579,
 6640,
 6673,
 6833,
 6904,
 6905,
 7008,
 7081,
 7136,
 7182,
 7234,
 7320,
 7398,
 7473,
 7958,
 7974,
 8004,
 8008,
 8177,
 8250,
 8348,
 8408,
 8510,
 8748,
 8952,
 9130,
 9133,
 9224,
 9299,
 9700,
 10052,
 10120,
 10353,
 10356,
 10639,
 10642,
 10673,
 10734,
 10850,
 11065,
 11067
 )
 order by pcf.id


12 by 12 by 12 auction


select  pc.west_mrn
      , pc.accession_nbr_formatted
      , pc.snomed_name
      , pc.note_text
      , pcf.genetic_abnormality_name
      , pcf.status
      , pcfn.*
from pathology_cases pc join pathology_case_findings pcf on pc.id = pcf.pathology_case_id
                        left join pathology_case_finding_normalizations pcfn on pcf.id = pcfn.pathology_case_finding_id
-- where pcf.genetic_abnormality_name like '%mutation%'
-- where   pc.accession_nbr_formatted  ='1-FI-19-0002556'
where pcf.genetic_abnormality_name != ':'
and lower(pcf.genetic_abnormality_name) != 'negative'
and lower(pcf.genetic_abnormality_name) != 'positive'
-- and pcf.genetic_abnormality_name like '%fusion%'
--  and pcf.genetic_abnormality_name = 'Gain of 5p15.2 with deletion of EGR1 (5q31)'


and  pcfn.normalization_name is  null
order by pcf.genetic_abnormality_name

select  pc.west_mrn
      , pc.accession_nbr_formatted
			, pc.snomed_name
			, pc.note_text
			, pcf.genetic_abnormality_name
			, pcf.status
      -- , pcf.matched_og_phrase
			, pcf.id
from pathology_cases  pc  join pathology_case_findings pcf on pc.id = pcf.pathology_case_id
order by pcf.genetic_abnormality_name

select *
from chromosomal_abnormalities  left join chromosomal_abnormality_genes on chromosomal_abnormalities.id = chromosomal_abnormality_genes.chromosomal_abnormality_id
                                left join gene_abnormalities on chromosomal_abnormality_genes.gene_abnormality_id = gene_abnormalities.id
-- where abnormality = '?'
order by abnormality_class, abnormality, gene_abnormality




-- CHIC2 (4q12) deletion/PDGFRA rearrangement
-- Gain of 5p15.2 with deletion of EGR1 (5q31)


select  pc.west_mrn
      , pc.accession_nbr_formatted
      , pc.snomed_name
      , pc.note_text
      , pcf.genetic_abnormality_name
      , pcf.status
      , pcfn.*
from pathology_cases pc join pathology_case_findings pcf on pc.id = pcf.pathology_case_id
                        left join pathology_case_finding_normalizations pcfn on pcf.id = pcfn.pathology_case_finding_id
-- where pcf.genetic_abnormality_name like '%mutation%'
-- where   pc.accession_nbr_formatted  ='1-FI-19-0002556'
where pcf.genetic_abnormality_name != ':'
and lower(pcf.genetic_abnormality_name) != 'negative'
and lower(pcf.genetic_abnormality_name) != 'positive'
-- and pcf.genetic_abnormality_name like '%fusion%'
--  and pcf.genetic_abnormality_name = 'Gain of 5p15.2 with deletion of EGR1 (5q31)'
and  pcf.id IN(
15,
 16,
 345,
 398,
 399,
 413,
 420,
 421,
 564,
 633,
 655,
 864,
 1024,
 1129,
 1131,
 1693,
 1855,
 1940,
 1959,
 2010,
 2069,
 2233,
 2326,
 2367,
 2478,
 2479,
 2772,
 2930,
 2935,
 3030,
 3032,
 3238,
 3239,
 3266,
 3507,
 3534,
 3758,
 3819,
 3955,
 4599,
 4685,
 4744,
 4877,
 4923,
 4968,
 5044,
 5210,
 5389,
 5542,
 5546,
 5651,
 5667,
 5668,
 5669,
 5709,
 5741,
 5869,
 5872,
 5875,
 5930,
 5969,
 6007,
 6282,
 6495,
 6579,
 6640,
 6673,
 6833,
 6904,
 6905,
 7008,
 7081,
 7136,
 7182,
 7234,
 7320,
 7398,
 7473,
 7958,
 7974,
 8004,
 8008,
 8177,
 8250,
 8348,
 8408,
 8510,
 8748,
 8952,
 9130,
 9133,
 9224,
 9299,
 9700,
 10052,
 10120,
 10353,
 10356,
 10639,
 10642,
 10673,
 10734,
 10850,
 11065,
 11067
 )
 order by pcf.id